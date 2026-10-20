"""Runs the training notebook as if on Colab: fake google.colab and kagglehub
modules, datasets "downloaded" from the fake Kaggle layout, Drive in a local
folder. COLAB_ROOT sets where /content would be.

    python tool/train/test/run_fake_colab.py <notebook.py> <fake input folder>
"""
import os
import runpy
import subprocess
import sys
import types

FAKE = os.path.abspath(sys.argv[2])
downloads = []

colab = types.ModuleType('google.colab')
colab.userdata = types.SimpleNamespace(
    get=lambda key: 'KGAT_fake' if key == 'KAGGLE_API_TOKEN' else None)
colab.drive = types.SimpleNamespace(
    mount=lambda path: os.makedirs(os.path.join(path, 'MyDrive'), exist_ok=True),
    flush_and_unmount=lambda: None)
import google.protobuf  # noqa: E402,F401  the real google namespace package
import google  # noqa: E402

google.colab = colab
sys.modules['google.colab'] = colab


def dataset_download(ref):
    owner, slug = ref.split('/')
    downloads.append(ref)
    return os.path.join(FAKE, 'datasets', owner, slug)


sys.modules['kagglehub'] = types.SimpleNamespace(dataset_download=dataset_download)

if os.name == 'nt':
    def junction(src, dst):   # Windows symlinks need admin rights
        subprocess.run(['cmd', '/c', 'mklink', '/J', dst, src], check=True,
                       capture_output=True)

    os.symlink = junction

pip_calls = []
_run = subprocess.run
subprocess.run = lambda args, **kw: (pip_calls.append(args) if 'pip' in args
                                      else _run(args, **kw))
runpy.run_path(sys.argv[1], run_name='__main__')
print('downloaded:', downloads, '| pip:', [a[-1] for a in pip_calls])
