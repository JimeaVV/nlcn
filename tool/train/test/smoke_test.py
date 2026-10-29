"""Runs the training notebook end to end on tiny fake data, on the CPU, and
checks what it leaves behind. Use it after every change to
train_food_model.py, before sending the notebook to Kaggle or Colab.

    python tool/train/test/smoke_test.py               # one device
    python tool/train/test/smoke_test.py --two-devices # like Kaggle's T4 x2
    python tool/train/test/smoke_test.py --resume      # cut off, then resume
    python tool/train/test/smoke_test.py --colab       # fake Colab and Drive
    python tool/train/test/smoke_test.py --nan         # NaN weights in epoch 2

Needs a Python with tensorflow 2.18 and pillow; the first run downloads the
backbone's ImageNet weights. The fake input also holds a 1.4-shaped model
(65 dishes + khac, random weights), so `EXPERIMENT = 'continue'` is tested
too: the run must find it and continue from it. Runs the quick test with 3 fine-tuning epochs
instead of 1, since some bugs only show from the second epoch on. Each run
takes 3–6 minutes. The logs stay in the work folder it prints.
"""
import argparse
import ast
import csv
import json
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
NOTEBOOK = os.path.join(HERE, '..', 'train_food_model.py')
sys.path.insert(0, HERE)
from make_fake_input import make  # noqa: E402

EXPORTS = ['food_v1.tflite', 'food_v1_int8.tflite', 'dishes.txt',
           'components.txt', 'MODEL_CARD.md', 'results.json']


def patched(source, backbone):
    """The notebook with 3 fine-tuning epochs in the quick test, a hook that
    ends the process after a given epoch (CRASH_AFTER=fine1), and one that
    turns the last layers' weights into NaN after the first batch of an
    epoch (NAN_AT=fine2)."""
    with open(source, encoding='utf-8') as f:
        s = f.read()

    def rep(old, new):
        nonlocal s
        if s.count(old) != 1:
            sys.exit(f'smoke_test: cannot patch the notebook, {old[:50]!r} '
                     'is not there once. Update smoke_test.py.')
        s = s.replace(old, new)

    rep("EPOCHS_FINE = (1 if QUICK_TEST", "EPOCHS_FINE = (3 if QUICK_TEST")
    s = re.sub(r'^QUICK_TEST = False', 'QUICK_TEST = True', s, count=1,
               flags=re.M)
    if backbone:
        s = re.sub(r"^BACKBONE = '[a-z0-9]+'", f"BACKBONE = '{backbone}'", s,
                   count=1, flags=re.M)
    rep("    os.replace(PROGRESS + '.tmp', PROGRESS)\n",
        "    os.replace(PROGRESS + '.tmp', PROGRESS)\n"
        "    if os.environ.get('CRASH_AFTER') == f'{phase}{epoch + 1}':\n"
        "        os._exit(3)   # smoke test: a session cut off here\n")
    rep("    def on_train_batch_end(self, batch, logs=None):\n"
        "        loss = (logs or {}).get('loss')\n",
        "    def on_train_batch_end(self, batch, logs=None):\n"
        "        if (os.environ.get('NAN_AT') == f'{self.phase}{self.epoch + 1}'\n"
        "                and batch == 0 and not os.environ.get('_NAN_DONE')):\n"
        "            os.environ['_NAN_DONE'] = '1'   # smoke test: poison it\n"
        "            for w in self.model.trainable_weights[-2:]:\n"
        "                w.assign(tf.fill(w.shape, float('nan')))\n"
        "        loss = (logs or {}).get('loss')\n")
    return s


def make_old_model(path, notebook):
    """A model shaped like contract 1.4's (65 dishes + khac, 25 components),
    built by the notebook's own build_model, with random weights."""
    with open(notebook, encoding='utf-8') as f:
        s = f.read()
    settings = s[:s.index('# %% [markdown]\n# ## On Google Colab')]
    model_cell = s[s.index('def build_model():'):s.index('def masked_bce(')]
    script = (settings + '\nfrom tensorflow import keras\n'
              'N_DISH, N_COMP = PREVIOUS_DISHES + 1, 25\n'
              'EXPERIMENT = "scratch"\n' + model_cell +
              f'\nm, _ = build_model()\nm.save({path!r})\n')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    subprocess.run([sys.executable, '-c', script], check=True,
                   env={**os.environ, 'TF_CPP_MIN_LOG_LEVEL': '3'})


def run(args, work, env_extra, name):
    nb = os.path.join(work, 'notebook.py')
    if args.colab:
        command = [os.path.join(HERE, 'run_fake_colab.py'), nb,
                   os.path.join(work, 'input')]
    elif args.two_devices:
        command = [os.path.join(HERE, 'run_two_devices.py'), nb]
    else:
        command = [nb]
    env = {**os.environ, 'TF_CPP_MIN_LOG_LEVEL': '3',
           'INPUT_ROOT': os.path.join(work, 'input'),
           'OUTPUT_DIR': os.path.join(work, 'output'),
           'SHRUNK_DIR': os.path.join(work, 'shrunk'),
           'COLAB_ROOT': os.path.join(work, 'colab'),
           'DOWNLOAD_URL_DATASETS': '0', **env_extra}
    log = os.path.join(work, f'{name}.log')
    with open(log, 'w', encoding='utf-8') as f:
        code = subprocess.run([sys.executable, '-X', 'utf8', *command],
                              env=env, stdout=f, stderr=subprocess.STDOUT,
                              timeout=1800).returncode
    with open(log, encoding='utf-8', errors='replace') as f:
        text = f.read()
    print(f'--- {name} (exit {code})')
    for line in re.findall(r'\[ *[0-9.]+ min\] [^\[\n]*', text):
        print('   ', line.strip())
    return code, text


def drive_folder(work):
    return os.path.join(work, 'colab', 'drive', 'MyDrive', 'macrorunner_train')


def output_dir(args, work):
    if args.colab:
        drive = drive_folder(work)
        # The run's own folder; the 1.4 model and the photo zips sit beside it.
        folders = [f for f in (os.listdir(drive) if os.path.isdir(drive) else [])
                   if f.endswith('_quick')]
        return os.path.join(drive, folders[0]) if folders else drive
    return os.path.join(work, 'output')


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--two-devices', action='store_true')
    mode.add_argument('--colab', action='store_true')
    parser.add_argument('--resume', action='store_true',
                        help='end the first run after fine epoch 1, resume')
    parser.add_argument('--nan', action='store_true',
                        help='NaN weights in fine epoch 2: must roll back')
    parser.add_argument('--backbone', help='e.g. efficientnetb0 (faster)')
    parser.add_argument('--source', default=NOTEBOOK)
    args = parser.parse_args()

    work = tempfile.mkdtemp(prefix='nb_smoke_')
    print('work folder:', work)
    make(os.path.join(work, 'input'))
    with open(os.path.join(work, 'notebook.py'), 'w', encoding='utf-8',
              newline='\n') as f:
        f.write(patched(args.source, args.backbone))
    if args.colab:
        # Where Colab looks: the 1.4 run's Drive folder, and the photo zips
        # in my_photos/. The fake Kaggle downloads hold neither.
        backbone = args.backbone or re.search(
            r"^BACKBONE = '([a-z0-9]+)'", open(args.source, encoding='utf-8')
            .read(), re.M).group(1)
        old_model = os.path.join(drive_folder(work), f'{backbone}_finetune',
                                 'checkpoint.keras')
        import shutil
        os.makedirs(os.path.join(drive_folder(work), 'my_photos'))
        shutil.make_archive(
            os.path.join(drive_folder(work), 'my_photos', 'export'), 'zip',
            os.path.join(work, 'input', 'datasets', 'me', 'my-photos'))
    else:
        old_model = os.path.join(work, 'input', 'datasets', 'me', 'b3-14',
                                 'checkpoint.keras')
    make_old_model(old_model, os.path.join(work, 'notebook.py'))

    problems = []
    first = ''
    if args.resume:
        code, first = run(args, work, {'CRASH_AFTER': 'fine1'}, 'run1_cut_off')
        if code != 3:
            problems.append(f'the cut-off run exited {code}, not 3')
    code, text = run(args, work, {'NAN_AT': 'fine2'} if args.nan else {},
                     'run2' if args.resume else 'run')
    if code != 0:
        problems.append(f'the notebook exited {code}; see the log')
    if 'AlreadyExistsError' in text or 'Traceback' in text:
        problems.append('a Python error is in the log')
    with open(args.source, encoding='utf-8') as f:
        continuing = "EXPERIMENT = 'continue'" in f.read()
    # A resumed run continues its own epochs; the first one used the model.
    if continuing and 'continuing from' not in first + text:
        problems.append('the run did not continue from the 1.4 model')
    # The new sources: Food-101 (pizza, steak), MyFood, VietFood67 crops and
    # the app's photos.
    found = re.search(r'Dishes without photos \(shoot these\): (\[.*\])', text)
    without = ast.literal_eval(found.group(1)) if found else []
    # MyFood (uc_ga) is downloaded, which the tests switch off; only the
    # fake Kaggle input has a copy.
    for dish in ('pizza', 'bo_bit_tet', 'com_trang', 'rau_xao') + (
            () if args.colab else ('uc_ga',)):
        if not found or dish in without:
            problems.append(f'no photos of {dish} were collected')
    if 'own photos: single_bi' not in text:
        problems.append('the photo zip label single_bi was not skipped')
    if args.resume and 'resuming fine-tuning after epoch 1' not in text:
        problems.append('the second run did not resume after epoch 1')
    if args.nan and 'going back to the end of fine epoch 1' not in text:
        problems.append('the NaN in fine epoch 2 did not roll back to epoch 1')

    out = output_dir(args, work)
    missing = [f for f in EXPORTS if not os.path.exists(os.path.join(out, f))]
    if missing:
        problems.append(f'missing in {out}: {missing}')
    if os.path.exists(os.path.join(out, 'results.json')):
        with open(os.path.join(out, 'results.json'), encoding='utf-8') as f:
            results = json.load(f)
        if not results.get('finished') or results.get('epochs_fine_done') != 3:
            problems.append('results.json: finished '
                            f"{results.get('finished')}, fine epochs "
                            f"{results.get('epochs_fine_done')} (want True, 3)")
        print('results: dish top-1', results.get('dish_top1'),
              '| train minutes', results.get('train_minutes'))
    log_path = os.path.join(out, 'training_log_fine.csv')
    if os.path.exists(log_path):
        with open(log_path, encoding='utf-8') as f:
            # Rows of epochs thrown away for a NaN loss stay in the log.
            rows = [r for r in csv.DictReader(f) if r['loss'] != 'nan']
        if [r['epoch'] for r in rows] != ['0', '1', '2']:
            problems.append('training_log_fine.csv epochs '
                            f"{[r['epoch'] for r in rows]}, want 0, 1, 2")
    leftovers = [f for f in os.listdir(out) if '.tmp' in f] \
        if os.path.isdir(out) else []
    if leftovers:
        problems.append(f'temporary files left: {leftovers}')

    if problems:
        print('FAIL')
        for p in problems:
            print('  -', p)
        print('logs in', work)
        sys.exit(1)
    print('PASS  (logs in', work + ')')


if __name__ == '__main__':
    main()
