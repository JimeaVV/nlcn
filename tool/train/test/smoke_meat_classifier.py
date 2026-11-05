"""Runs the meat classifier notebook end to end on tiny fake data, on the
CPU, and checks the files it leaves behind. Also checks that the crop
tool/train/eval_meat_classifier.py cuts (and the app cuts the same way) is
the one the notebook trains on. Use it after every change to
train_meat_classifier.py, before sending the notebook to Kaggle or Colab.

    python tool/train/test/smoke_meat_classifier.py

Needs a Python with tensorflow 2.18 and pillow. Starts from an untrained
MobileNetV3Small (no download). Takes 1–3 minutes. The log stays in the
work folder it prints.
"""
import json
import os
import random
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
NOTEBOOK = os.path.join(HERE, '..', 'train_meat_classifier.py')
sys.path.insert(0, os.path.join(HERE, '..'))
# VietFood67 ids: 25 Com, 51 Thit ga, 52 Thit heo, 46 Pho (a whole dish).
COLOURS = {25: (240, 240, 230), 51: (200, 150, 90), 52: (190, 120, 110),
           46: (180, 120, 60)}


def make(root):
    rng = random.Random(0)
    vf = os.path.join(root, 'input', 'vietfood68', 'dataset')
    for split, count in (('train', 16), ('valid', 4), ('test', 4)):
        os.makedirs(os.path.join(vf, 'images', split), exist_ok=True)
        os.makedirs(os.path.join(vf, 'labels', split), exist_ok=True)
        for i in range(count):
            ids = [25, 51 if i % 2 else 52] + ([46] if i % 4 == 0 else [])
            # Large photos, so the notebook has to shrink them.
            im = Image.new('RGB', (1200, 900), (60, 60, 70))
            draw = ImageDraw.Draw(im)
            lines = []
            for j, c in enumerate(ids):
                cx = 0.2 + 0.3 * j + rng.uniform(-0.03, 0.03)
                cy, w, h = 0.5 + rng.uniform(-0.1, 0.1), 0.22, 0.3
                draw.rectangle(((cx - w / 2) * 1200, (cy - h / 2) * 900,
                                (cx + w / 2) * 1200, (cy + h / 2) * 900),
                               fill=COLOURS[c])
                lines.append(f'{c} {cx:.4f} {cy:.4f} {w} {h}\n')
            im.save(os.path.join(vf, 'images', split, f'p{i}.jpg'))
            with open(os.path.join(vf, 'labels', split, f'p{i}.txt'), 'w') as f:
                f.writelines(lines)
    # MyFood: a chicken breast (value 5) and rice (6).
    myfood = os.path.join(root, 'work', 'extra', 'myfood', 'MyFood Dataset')
    for split in ('train', 'val', 'test'):
        os.makedirs(os.path.join(myfood, split), exist_ok=True)
        os.makedirs(os.path.join(myfood, f'{split}_ann'), exist_ok=True)
        for i in range(3):
            im = Image.new('RGB', (320, 240), (90, 90, 90))
            mask = Image.new('L', (320, 240), 0)
            for draw, fills in ((ImageDraw.Draw(im), ((250, 250, 240),
                                                      (210, 170, 120))),
                                (ImageDraw.Draw(mask), (6, 5))):
                draw.rectangle((10, 10, 150, 200), fill=fills[0])
                draw.ellipse((180, 40, 290, 170), fill=fills[1])
            im.save(os.path.join(myfood, split, f'lunch_{i}.png'))
            mask.save(os.path.join(myfood, f'{split}_ann', f'lunch_{i}.png'))
    # FoodInsSeg: rice with two touching pork slices (joined into one box)
    # and a fish; ids 0–5 in Test.json are halved into val and test.
    fis = os.path.join(root, 'work', 'extra', 'foodinsseg')
    os.makedirs(os.path.join(fis, 'annotations'), exist_ok=True)
    names = ['rice', 'pork', 'chicken duck', 'steak', 'fish', 'shrimp',
             'fried meat'] + sorted({
                 'egg', 'tofu', 'french fries', 'cucumber', 'tomato',
                 'lettuce', 'broccoli', 'cabbage', 'bean sprouts', 'rape',
                 'noodles', 'pasta', 'bread', 'corn', 'carrot', 'potato',
                 'green beans', 'French beans', 'asparagus', 'cauliflower',
                 'eggplant', 'pumpkin', 'white radish', 'okra', 'snow peas',
                 'pepper', 'onion', 'white button mushroom', 'shiitake',
                 'soy', 'red beans', 'soup', 'sausage', 'wonton dumplings',
                 'hanamaki baozi', 'hamburg', 'salad', 'other ingredients'})
    categories = [{'id': 100 + i, 'name': n} for i, n in enumerate(names)]
    fills = {100: (245, 245, 235), 101: (190, 150, 130), 104: (230, 200, 160),
             106: (150, 90, 40)}
    for json_name, folder in (('Train.json', 'train'), ('Test.json', 'test')):
        os.makedirs(os.path.join(fis, 'images', folder), exist_ok=True)
        images, annotations = [], []
        for i in range(8 if folder == 'train' else 6):
            im = Image.new('RGB', (512, 384), (70, 60, 60))
            draw = ImageDraw.Draw(im)
            boxes = [(100, [30, 40, 200, 200]), (101, [300, 60, 60, 70]),
                     (101, [362, 60, 60, 70]), (104, [260, 230, 160, 90])]
            if i == 0:
                boxes.append((106, [60, 280, 80, 60]))   # fried meat
            for category, (left, top, w, h) in boxes:
                draw.rectangle((left, top, left + w, top + h),
                               fill=fills[category])
                annotations.append({'id': len(annotations), 'image_id': i,
                                    'category_id': category,
                                    'bbox': [left, top, w, h]})
            name = f'{folder}{i:03d}.jpg'
            im.save(os.path.join(fis, 'images', folder, name))
            images.append({'id': i, 'width': 512, 'height': 384,
                           'file_name': name})
        with open(os.path.join(fis, 'annotations', json_name), 'w') as f:
            json.dump({'images': images, 'annotations': annotations,
                       'categories': categories}, f)


def check_crop():
    """eval_meat_classifier.crop against tf.image.crop_and_resize, which
    the notebook trains with."""
    import tensorflow as tf
    from eval_meat_classifier import crop
    rng = np.random.default_rng(0)
    size, place = 64, (3, 10, 58, 41)    # a photo fitted into a 64 input
    image = rng.random((size, size, 3), np.float32)
    left, top, w, h = place
    photo = image[top:top + h, left:left + w] * 255
    pad = 0.1
    for box in [(0.1, 0.2, 0.5, 0.7), (0.0, 0.0, 1.0, 1.0), (0.6, 0.5, 0.95, 0.9)]:
        ours = crop(image, place, box, pad, 24)
        bw, bh = box[2] - box[0], box[3] - box[1]
        region = [max(0.0, box[1] - pad * bh), max(0.0, box[0] - pad * bw),
                  min(1.0, box[3] + pad * bh), min(1.0, box[2] + pad * bw)]
        theirs = tf.image.crop_and_resize(photo[None], [region], [0], [24, 24],
                                          method='bilinear')[0].numpy()
        assert np.abs(ours - theirs).max() < 1e-3, (box, np.abs(ours - theirs).max())


def main():
    check_crop()
    print('crop matches tf.image.crop_and_resize')
    work = tempfile.mkdtemp(prefix='meat_smoke_')
    print('work folder', work)
    make(work)
    env = {**os.environ, 'PYTHONIOENCODING': 'utf-8', 'TF_CPP_MIN_LOG_LEVEL': '3',
           'INPUT_ROOT': os.path.join(work, 'input'),
           'OUTPUT_DIR': os.path.join(work, 'output'),
           'WORK_DIR': os.path.join(work, 'work'),
           'BACKBONE': 'mobilenetv3small', 'WEIGHTS': 'none',
           'DOWNLOAD_MYFOOD': '0', 'DOWNLOAD_FOODINSSEG': '0'}
    log = os.path.join(work, 'run.log')
    with open(log, 'w', encoding='utf-8') as f:
        code = subprocess.run([sys.executable, NOTEBOOK], stdout=f,
                              stderr=subprocess.STDOUT, cwd=work, env=env).returncode
    with open(log, encoding='utf-8') as f:
        text = f.read()
    if code:
        print(text[-4000:])
        sys.exit(f'smoke_meat_classifier: the run failed, log {log}')
    # VietFood67: 24 meat boxes and 24 rice boxes, the pho boxes left out;
    # FoodInsSeg: per photo one joined pork box and a fish, rice as khac.
    assert 'VietFood67: 24 images, 24 label files' in text, text[-3000:]
    assert 'Shrinking' in text and 'Training done' in text, text[-3000:]
    for source in ("'fis'", "'vf67'", "'fis_empty'", "'myfood'"):
        assert source in text.split('Sources:')[1].split('\n')[0], source
    output = os.path.join(work, 'output')
    for name in ('meat_classifier.tflite', 'meat_classes.txt', 'MEAT_CARD.md',
                 'results.json'):
        assert os.path.exists(os.path.join(output, name)), name
    with open(os.path.join(output, 'meat_classes.txt')) as f:
        classes = f.read().split()
    assert classes == ['ga', 'thit_kho', 'thit_nuong', 'heo', 'bo', 'ca', 'tom',
                       'khac'], classes
    with open(os.path.join(output, 'MEAT_CARD.md'), encoding='utf-8') as f:
        card = f.read()
    for line in ('contract_version: 1.8', 'crop_pad: 0.10',
                 'threshold_rename: 0.70', 'QUICK TEST'):
        assert line in card, (line, card)
    with open(os.path.join(output, 'results.json')) as f:
        results = json.load(f)
    crops = results['crops']
    assert crops['val'] and crops['test'], crops
    # The shrunk photos keep the long side at 512, as the app's input.
    small = os.path.join(work, 'work', 'small')
    sizes = {Image.open(os.path.join(small, n)).size for n in os.listdir(small)}
    assert all(max(s) == 512 for s in sizes), sizes
    import tensorflow as tf
    lite = tf.lite.Interpreter(os.path.join(output, 'meat_classifier.tflite'))
    lite.allocate_tensors()
    (inp,), (out,) = lite.get_input_details(), lite.get_output_details()
    assert list(inp['shape']) == [1, 224, 224, 3], inp['shape']
    assert list(out['shape']) == [1, 8], out['shape']
    lite.set_tensor(inp['index'], np.full((1, 224, 224, 3), 128, np.float32))
    lite.invoke()
    p = lite.get_tensor(out['index'])[0]
    assert abs(p.sum() - 1) < 1e-3, p
    print('smoke_meat_classifier: OK')


if __name__ == '__main__':
    main()
