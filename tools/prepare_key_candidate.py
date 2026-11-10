#!/usr/bin/env python3
"""Convert the published 2018 key CNN for local, non-commercial evaluation."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import torch
from torch import nn


class KeyCandidate(nn.Module):
    def __init__(self, original):
        super().__init__()
        converted = []
        for layer in original.layers:
            name = type(layer).__name__
            if name == 'PadLayer':
                converted.append(nn.ZeroPad2d(layer.width))
            elif name == 'ConvolutionalLayer':
                weights = layer.weights.transpose(1, 0, 2, 3)[:, :, ::-1, ::-1].copy()
                convolution = nn.Conv2d(weights.shape[1], weights.shape[0], weights.shape[2:])
                convolution.weight.data.copy_(torch.from_numpy(weights))
                convolution.bias.data.copy_(torch.from_numpy(np.broadcast_to(layer.bias, (weights.shape[0],)).copy()))
                converted.append(convolution)
            elif name == 'BatchNormLayer':
                scale = layer.gamma * layer.inv_std
                bias = layer.beta - layer.mean * scale
                affine = nn.Conv2d(len(scale), len(scale), 1, groups=len(scale))
                affine.weight.data.copy_(torch.from_numpy(scale.reshape(-1, 1, 1, 1)))
                affine.bias.data.copy_(torch.from_numpy(bias))
                converted.extend([affine, nn.ELU()])
            elif name == 'MaxPoolLayer':
                converted.append(nn.MaxPool2d(layer.size, layer.stride))
            elif name != 'AverageLayer':
                raise ValueError('Unsupported key model layer: ' + name)
        self.layers = nn.Sequential(*converted)

    def forward(self, spectrogram):
        return self.layers(spectrogram).mean(dim=3)


def main():
    from madmom.audio.filters import LogarithmicFilterbank
    from madmom.audio.stft import fft_frequencies
    from madmom.features.key import CNNKeyRecognitionProcessor
    from madmom.ml.nn import NeuralNetwork
    from madmom.models import KEY_CNN
    import coremltools as ct

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('audio', type=Path, help='Audio used for conversion parity checks.')
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    if args.output.exists():
        parser.error('Choose a new candidate folder. Existing evidence was retained.')
    torch.set_num_threads(1)
    processor = CNNKeyRecognitionProcessor()
    features = args.audio.as_posix()
    for stage in processor.processors[:4]:
        features = stage(features)
    features = np.asarray(features, dtype=np.float32)
    weights = Path(KEY_CNN[0])
    weights_sha = hashlib.sha256(weights.read_bytes()).hexdigest()
    assert weights_sha == 'c58ba553be1048877662a663a2670c0051b3c2c66d109b6042ba722ed0bfc7a6', 'Key model weights changed.'
    original = NeuralNetwork.load(str(weights))
    model = KeyCandidate(original).eval()
    frames, bands = 600, 105
    assert features.shape[1] == bands, features.shape
    sample = np.zeros((frames, bands), dtype=np.float32)
    sample[:min(frames, len(features))] = features[:frames]
    expected = original(sample)
    tensor = torch.from_numpy(sample[None, None])
    with torch.no_grad():
        actual = model(tensor).mean(dim=2).numpy()[0]
    error = float(np.max(np.abs(actual - expected)))
    assert error < 0.002, ('Original/Torch parity failed', error)
    traced = torch.jit.trace(model, tensor)
    converted = ct.convert(traced, inputs=[ct.TensorType(name='spectrogram', shape=tensor.shape)],
                           outputs=[ct.TensorType(name='logits', dtype=np.float32)],
                           compute_precision=ct.precision.FLOAT16,
                           minimum_deployment_target=ct.target.iOS17)
    coreml = converted.predict({'spectrogram': tensor.numpy()})['logits'].mean(axis=2)[0]
    coreml_error = float(np.max(np.abs(coreml - actual)))
    assert coreml_error < 0.03, ('Torch/CoreML parity failed', coreml_error)
    assert int(coreml.argmax()) == int(actual.argmax()), 'CoreML changed the reference key.'
    args.output.mkdir(parents=True)
    converted.save(args.output / 'KeyCandidate.mlpackage')
    filters = np.asarray(LogarithmicFilterbank(fft_frequencies(4096, 44100), num_bands=24,
                                             fmin=65, fmax=2100, unique_filters=True), dtype=np.float32)
    assert filters.shape == (4096, bands), filters.shape
    filters.T.copy().tofile(args.output / 'filters.f32')
    features.tofile(args.output / 'reference-features.f32')
    model_id = 'madmom-key-cnn-2018-eval1'
    metadata = {
        'format': 'generik.key-candidate/v1', 'modelID': model_id,
        'weightsSHA256': weights_sha,
        'source': 'https://github.com/CPJKU/madmom_models/tree/7e3dc1b0cad499792767074d03c38b194b9b0a79/key/2018',
        'computePrecision': 'float16',
        'license': 'CC-BY-NC-SA-4.0. Local evaluation only. Not bundled with the application.',
        'preprocessingVersion': 1, 'conversionVersion': 1, 'decisionPolicyVersion': 1,
        'sampleRate': 44100, 'fftSize': 8192, 'hop': 8820, 'bands': bands, 'windowFrames': frames,
        'classOrder': [{'tonic': (i % 12 + 9) % 12, 'mode': 'major' if i < 12 else 'minor'} for i in range(24)],
        'aggregation': 'Mean valid output frames from consecutive 120-second windows, then softmax. Short final windows use zero padding.',
        'originalTorchMaxError': error, 'torchCoreMLMaxError': coreml_error,
        'referenceAudioSHA256': hashlib.sha256(args.audio.read_bytes()).hexdigest(),
        'referenceFeatureFrames': len(features),
        'filtersSHA256': hashlib.sha256((args.output / 'filters.f32').read_bytes()).hexdigest(),
        'referenceFeaturesSHA256': hashlib.sha256((args.output / 'reference-features.f32').read_bytes()).hexdigest(),
    }
    (args.output / 'profile.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print(json.dumps(metadata, indent=2))


if __name__ == '__main__':
    main()
