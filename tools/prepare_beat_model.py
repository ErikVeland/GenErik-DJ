"""Export the pinned Beat This checkpoint for Neural Engine evaluation."""
# Conversion environment: Python 3.12, coremltools 9.0, torch/torchaudio 2.7.1, numpy 1.26.4, beat-this 1.1.0.
import argparse
import hashlib
import json
from pathlib import Path

import coremltools as ct
import numpy as np
import torch
from beat_this.inference import load_model
import rotary_embedding_torch.rotary_embedding_torch as rotary

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--checkpoint", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
expected_hash = "6074be2c4d490c5f6101fcc374a1ec72ae93456e23bb6019783b849f5dc7d47b"
if hashlib.sha256(args.checkpoint.read_bytes()).hexdigest() != expected_hash:
    raise ValueError("The Beat This checkpoint does not match the pinned version.")
if args.output.exists():
    raise ValueError("The output already exists. Choose a new path.")
torch.manual_seed(0)
torch.set_num_threads(2)
model = load_model(args.checkpoint)
class Rhythm(torch.nn.Module):
    def __init__(self):
        super().__init__()
        self.model = model
    def forward(self, spectrogram):
        logits = self.model(spectrogram)
        return logits["beat"], logits["downbeat"]

module = Rhythm().eval()
spectrogram = torch.rand(1, 1500, 128)
with torch.no_grad():
    expected = module(spectrogram)
    einsum = rotary.einsum
    def convert_outer_product(equation, positions, frequencies):
        if equation == "..., f -> ... f":
            return positions.unsqueeze(-1) * frequencies
        return einsum(equation, positions, frequencies)
    rotary.einsum = convert_outer_product
    trace = torch.jit.trace(module, spectrogram, check_trace=False)
    export_path = trace(spectrogram)
    assert all(torch.equal(a, b) for a, b in zip(expected, export_path))
converted = ct.convert(
    trace,
    inputs=[ct.TensorType(name="spectrogram", shape=tuple(spectrogram.shape), dtype=np.float32)],
    outputs=[ct.TensorType(name="beats", dtype=np.float32), ct.TensorType(name="downbeats", dtype=np.float32)],
    minimum_deployment_target=ct.target.iOS17,
    compute_precision=ct.precision.FLOAT16,
    compute_units=ct.ComputeUnit.CPU_AND_NE,
)
converted.short_description = "Beat This small0, FP16 computation with FP32 input/output."
converted.user_defined_metadata["checkpointSHA256"] = expected_hash
converted.user_defined_metadata["variant"] = "small0-fp16-v1"
converted.save(args.output)
print(json.dumps({"output": str(args.output), "checkpointSHA256": expected_hash,
                  "coremltools": ct.__version__, "torch": torch.__version__}), flush=True)
