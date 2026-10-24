"""Runs the detector notebook end to end on tiny fake data, on the CPU, twice:
first cut off by a time limit after one epoch, then resumed to the end.
Checks the files it leaves behind. Use it after every change to
train_detector.py, before sending the notebook to Colab.

    python tool/train/test/smoke_detector.py

Needs a Python with ultralytics 8.4 (CPU torch is enough). Starts from an
untrained YOLO11n (no download). LiteRT export only works on Linux and
macOS, so on Windows the check runs on the ONNX copy instead. Takes 3–5
minutes. The logs stay in the work folder it prints.
"""
import json
import os
import random
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
NOTEBOOK = os.path.join(HERE, '..', 'train_detector.py')
# VietFood67 ids: 25 Com, 51 Thit ga, 56 Trung, 48 Rau, 24 Chanh, 46 Pho.
PLATES = {
    'plate': [25, 51, 48],
    'eggs': [25, 56, 56],
    'lime': [24],          # nothing of ours: background
    'pho': [46, 56],       # a whole-dish box: left out
}
COLOURS = {25: (240, 240, 230), 51: (200, 150, 90), 56: (250, 200, 40),
           48: (40, 160, 60), 24: (120, 220, 60), 46: (180, 120, 60)}


def make(root):
    rng = random.Random(0)
    vf = os.path.join(root, 'input', 'vietfood68', 'dataset')
    for split, count in (('train', 12), ('valid', 4), ('test', 4)):
        os.makedirs(os.path.join(vf, 'images', split), exist_ok=True)
        os.makedirs(os.path.join(vf, 'labels', split), exist_ok=True)
        for kind, ids in PLATES.items():
            for i in range(count):
                im = Image.new('RGB', (400, 300), (60, 60, 70))
                draw = ImageDraw.Draw(im)
                lines = []
                for j, c in enumerate(ids):
                    cx = 0.2 + 0.3 * j + rng.uniform(-0.03, 0.03)
                    cy, w, h = 0.5 + rng.uniform(-0.1, 0.1), 0.22, 0.3
                    draw.rectangle(((cx - w / 2) * 400, (cy - h / 2) * 300,
                                    (cx + w / 2) * 400, (cy + h / 2) * 300),
                                   fill=COLOURS[c])
                    lines.append(f'{c} {cx:.4f} {cy:.4f} {w} {h}\n')
                name = f'{kind}{i}'
                im.save(os.path.join(vf, 'images', split, name + '.jpg'))
                with open(os.path.join(vf, 'labels', split, name + '.txt'),
                          'w') as f:
                    f.writelines(lines)
    # MyFood: two eggs (value 4) as two pieces, and rice (6).
    myfood = os.path.join(root, 'work', 'extra', 'myfood', 'MyFood Dataset')
    for split in ('train', 'val', 'test'):
        os.makedirs(os.path.join(myfood, split), exist_ok=True)
        os.makedirs(os.path.join(myfood, f'{split}_ann'), exist_ok=True)
        for i in range(4):
            im = Image.new('RGB', (320, 240), (90, 90, 90))
            mask = Image.new('L', (320, 240), 0)
            for draw, fills in ((ImageDraw.Draw(im), ((250, 250, 240),
                                                      (250, 200, 40))),
                                (ImageDraw.Draw(mask), (6, 4))):
                draw.rectangle((10, 10, 150, 200), fill=fills[0])
                draw.ellipse((180, 20, 240, 80), fill=fills[1])
                draw.ellipse((200, 130, 260, 190), fill=fills[1])
            im.save(os.path.join(myfood, split, f'lunch_{i}.png'))
            mask.save(os.path.join(myfood, f'{split}_ann', f'lunch_{i}.png'))


def run(work, name, **env):
    log = os.path.join(work, f'{name}.log')
    with open(log, 'w', encoding='utf-8') as f:
        code = subprocess.run(
            [sys.executable, NOTEBOOK], stdout=f, stderr=subprocess.STDOUT,
            cwd=work, env={**os.environ, 'PYTHONIOENCODING': 'utf-8', **env}).returncode
    with open(log, encoding='utf-8') as f:
        text = f.read()
    if code:
        print(text[-4000:])
        sys.exit(f'smoke_detector: {name} run failed, log {log}')
    return text


def main():
    work = tempfile.mkdtemp(prefix='detector_smoke_')
    print('work folder', work)
    make(work)
    env = {'INPUT_ROOT': os.path.join(work, 'input'),
           'OUTPUT_DIR': os.path.join(work, 'output'),
           'WORK_DIR': os.path.join(work, 'work'),
           'MODEL': 'yolo11n.yaml', 'DOWNLOAD_MYFOOD': '0'}
    first = run(work, 'cut', TIME_LIMIT_HOURS='0.01', **env)
    assert 'Time limit: stopped after epoch 1 of 2' in first, first[-2000:]
    assert "'vf67: whole-dish box': 20" in first, 'pho photos not left out'
    second = run(work, 'resume', TIME_LIMIT_HOURS='0', **env)
    assert 'Resuming' in second, second[-2000:]
    assert 'Training done' in second
    export = os.path.join(work, 'output', 'export')
    for name in ('detector_classes.txt', 'DETECTOR_CARD.md', 'results.json',
                 'detector_best.pt'):
        assert os.path.exists(os.path.join(export, name)), name
    with open(os.path.join(export, 'detector_classes.txt')) as f:
        classes = f.read().split()
    assert len(classes) == 21 and classes[0] == 'com', classes
    with open(os.path.join(export, 'DETECTOR_CARD.md'), encoding='utf-8') as f:
        card = f.read()
    assert 'contract_version: 1.6' in card and 'threshold_box:' in card
    with open(os.path.join(export, 'results.json')) as f:
        results = json.load(f)
    assert 'app_decoding_matches' in results, 'exported model not checked'
    print(card)
    print('decoding check:', results['app_decoding_matches'],
          '| input', results['input_shape'], '| output', results['output_shape'])
    print('smoke_detector: OK')


if __name__ == '__main__':
    main()
