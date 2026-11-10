#!/usr/bin/env python3
"""Convert the pinned MIT MusicalKeyCNN checkpoint and its constant-Q filters."""
import argparse,hashlib,importlib.util,json,subprocess
from pathlib import Path
import numpy as np
import torch
import librosa
import librosa.core.constantq as cq
import coremltools as ct

REVISION='61d8fc170f262410f66a12057adffc5aceea0b2c'

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('source',type=Path);p.add_argument('audio',type=Path);p.add_argument('output',type=Path);a=p.parse_args()
 assert not a.output.exists(),'Choose a new model folder.'
 assert subprocess.check_output(['git','-C',str(a.source),'rev-parse','HEAD'],text=True).strip()==REVISION
 spec=importlib.util.spec_from_file_location('keynet_source',a.source/'model.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
 model=module.KeyNet().eval();checkpoint=a.source/'checkpoints/keynet.pt';model.load_state_dict(torch.load(checkpoint,map_location='cpu',weights_only=True));torch.set_num_threads(1)
 class Temporal(torch.nn.Module):
  def __init__(self,network):super().__init__();self.network=network
  def forward(self,x):
   x=x.transpose(2,3)
   for layer in [self.network.conv1,self.network.conv2,self.network.pool1,self.network.conv3,self.network.conv4,self.network.pool2,self.network.conv5,self.network.conv6,self.network.pool3,self.network.conv7,self.network.conv8,self.network.conv9]:x=layer(x)
   return x.mean(dim=2)
 wrapper=Temporal(model).eval();audio,_=librosa.load(a.audio,sr=44100,mono=True)
 features=np.log1p(abs(librosa.cqt(audio,sr=44100,hop_length=8820,n_bins=105,bins_per_octave=24,fmin=65)))[:,:-2].T.astype(np.float32)
 frames=min(600,len(features));tensor=torch.from_numpy(features[:frames][None,None]);traced=torch.jit.trace(wrapper,tensor)
 original=model(tensor.transpose(2,3)).detach().numpy()[0];actual=wrapper(tensor).mean(dim=2).detach().numpy()[0];assert np.max(abs(actual-original))<1e-5
 converted=ct.convert(traced,inputs=[ct.TensorType(name='spectrogram',shape=(1,1,ct.RangeDim(8,600,default=600),105))],outputs=[ct.TensorType(name='logits',dtype=np.float32)],compute_precision=ct.precision.FLOAT16,minimum_deployment_target=ct.target.iOS17)
 core=converted.predict({'spectrogram':tensor.numpy()})['logits'].mean(axis=2)[0];error=float(max(abs(core-actual)));assert error<.1 and core.argmax()==actual.argmax(),error
 a.output.mkdir(parents=True);converted.save(a.output/'KeyCandidate.mlpackage');features.tofile(a.output/'reference-features.f32')
 freqs=65*2**(np.arange(105)/24);alpha=librosa.filters._relative_bandwidth(freqs=freqs);lengths,_=librosa.filters.wavelet_lengths(freqs=freqs,sr=44100,alpha=alpha)
 groups=[];rate=44100;hop=8820
 for octave in range(5):
  start=max(0,105-24*(octave+1));end=105-24*octave
  basis,nfft,_=cq.__vqt_filter_fft(rate,freqs[start:end],1,1,.01,alpha=alpha[start:end]);basis=basis.toarray()*(44100/rate)/np.sqrt(lengths[start:end,None])
  filters=[]
  for row in basis:
   idx=np.flatnonzero(row);filters.append({'indices':idx.tolist(),'real':row[idx].real.tolist(),'imaginary':row[idx].imag.tolist()})
  groups.append({'sampleRate':rate,'hop':hop,'fftSize':nfft,'firstBand':start,'filters':filters})
  if hop%2==0:rate//=2;hop//=2
 (a.output/'cqt.json').write_text(json.dumps({'format':'generik.key-cqt/v1','groups':groups},separators=(',',':'))+'\n')
 classes=[{'tonic':(8+7*i)%12,'mode':'minor'} for i in range(12)]+[{'tonic':(11+7*i)%12,'mode':'major'} for i in range(12)]
 profile={'format':'generik.key-candidate/v1','modelID':'musical-key-cnn-mit-2025-v1','weightsSHA256':sha(checkpoint),'filtersSHA256':sha(a.output/'cqt.json'),'preprocessingVersion':1,'conversionVersion':1,'decisionPolicyVersion':1,'sampleRate':44100,'fftSize':0,'hop':8820,'bands':105,'windowFrames':600,'classOrder':classes,'licence':'MIT','sourceRevision':REVISION,'source':'https://github.com/a1ex90/MusicalKeyCNN','originalTorchMaxError':float(max(abs(original-actual))),'torchCoreMLMaxError':error,'referenceAudioSHA256':sha(a.audio),'referenceFeatureFrames':len(features),'referenceFeaturesSHA256':sha(a.output/'reference-features.f32'),'aggregation':'Mean temporal logits. Consecutive windows of up to 600 frames. Dynamic final window, minimum eight frames.'}
 (a.output/'profile.json').write_text(json.dumps(profile,indent=2)+'\n');(a.output/'LICENSE').write_bytes((a.source/'LICENSE').read_bytes());print(json.dumps(profile,indent=2))
if __name__=='__main__':main()
