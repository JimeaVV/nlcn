"""Checks the meat classifier on the plate detector's own boxes, the way the
app runs the two (contract 1.8, §9.3), and picks the thresholds for
MEAT_CARD.md.

    python tool/train/eval_meat_classifier.py TEST [--tune VAL]
        [--models assets/models] [--classifier meat_classifier.tflite]

TEST and VAL are folders of photos with the detector's classes as YOLO
labels (`images/`, `labels/`), e.g. FoodInsSeg's test half (odd ids) and val
half (even ids), which neither model trained on. The detector, its card and
the classifier's labels and card are read from --models; --classifier
points to another classifier file, e.g. one just downloaded from Kaggle.

For each photo: the detector as the app runs it (letterbox, per-class
thresholds from DETECTOR_CARD.md, per-class NMS), then each meat box cut out
of the detector's input and classified. Scores are per photo, as the app
shows them: a food found is one the photo has, a wrong find one it does not
have. With --tune, the thresholds are chosen on VAL and reported on TEST.

Needs a Python with tensorflow 2.18, pillow and numpy. About 3 minutes for
the 459 test photos on a laptop CPU; the detector's boxes are cached next to
the photos (`.meat_eval_cache_*.npz`) for the next run.
"""
import argparse
import glob
import itertools
import os
import re

import numpy as np
from PIL import Image, ImageOps
import tensorflow as tf

MEATS = ['ga', 'thit_kho', 'thit_nuong', 'heo', 'bo', 'ca', 'tom']
FLOOR = 0.05      # boxes below this score are never looked at
# run()'s settings and their lines in MEAT_CARD.md (contract §9.2).
CARD_LINES = {'rename': 'threshold_rename', 'fuse': 'vote_power',
              'floor': 'box_floor', 'rescue': 'threshold_rescue',
              'drop': 'threshold_drop'}


def card_value(card, key):
    match = re.search(rf'^{key}:\s*([0-9.]+)', card, re.M)
    return float(match.group(1)) if match else None


def letterbox(path, size):
    """The detector's input for one photo as the app makes it: the upright
    photo shrunk into size×size, centred, grey around it, values 0–1.
    Returns it with the fitted photo's place (left, top, width, height)."""
    with Image.open(path) as im:
        im = ImageOps.exif_transpose(im).convert('RGB')
        scale = size / max(im.size)
        w, h = max(1, round(im.width * scale)), max(1, round(im.height * scale))
        fitted = np.asarray(im.resize((w, h), Image.BILINEAR), np.float32) / 255
    left, top = (size - w) // 2, (size - h) // 2
    image = np.full((size, size, 3), 114 / 255, np.float32)
    image[top:top + h, left:left + w] = fitted
    return image, (left, top, w, h)


def nms(boxes, limit):
    """Per class, the best of boxes that overlap more than [limit]
    (decodeDetections in lib/models/plate_detection.dart)."""
    kept = []
    for b in sorted(boxes, key=lambda b: -b[1]):
        if all(k[0] != b[0] or iou(k[2], b[2]) <= limit for k in kept):
            kept.append(b)
    return kept


def iou(a, b):
    left, top = max(a[0], b[0]), max(a[1], b[1])
    right, bottom = min(a[2], b[2]), min(a[3], b[3])
    if right <= left or bottom <= top:
        return 0.0
    shared = (right - left) * (bottom - top)
    return shared / ((a[2] - a[0]) * (a[3] - a[1]) +
                     (b[2] - b[0]) * (b[3] - b[1]) - shared)


def detect(interpreter, image, place, n_classes, iou_limit, meat_ids):
    """Every box from FLOOR up, after per-class NMS: (class, score, box as
    shares of the photo, the box's score for each of [meat_ids]). A lower
    threshold applied afterwards gives what the app keeps, since a box is
    only ever suppressed by a better one."""
    (inp,), (out,) = interpreter.get_input_details(), interpreter.get_output_details()
    channels_first = inp['shape'][1] == 3
    x = image.transpose(2, 0, 1) if channels_first else image
    interpreter.set_tensor(inp['index'], x[None])
    interpreter.invoke()
    raw = interpreter.get_tensor(out['index'])[0]
    if raw.shape[0] != 4 + n_classes:
        raw = raw.T
    size = image.shape[0]
    unit = size if raw[2].max() > 2 else 1.0
    scores = raw[4:]
    best = scores.argmax(0)
    score = scores.max(0)
    left, top, w, h = place
    found = []
    for a in np.nonzero(score >= FLOOR)[0]:
        cx, cy, bw, bh = raw[:4, a] / unit * size
        box = (np.clip((cx - bw / 2 - left) / w, 0, 1),
               np.clip((cy - bh / 2 - top) / h, 0, 1),
               np.clip((cx + bw / 2 - left) / w, 0, 1),
               np.clip((cy + bh / 2 - top) / h, 0, 1))
        if box[2] > box[0] and box[3] > box[1]:
            found.append((int(best[a]), float(score[a]), tuple(map(float, box)),
                          scores[meat_ids, a].copy()))
    return nms(found, iou_limit)


def crop(image, place, box, pad, out_size):
    """The classifier's input for [box], as the app cuts it from the
    detector's input: the box grown by [pad] a side, kept on the photo,
    sampled bilinearly like tf.image.crop_and_resize. RGB 0–255."""
    left, top, w, h = place
    bw, bh = box[2] - box[0], box[3] - box[1]
    x0, x1 = max(0.0, box[0] - pad * bw), min(1.0, box[2] + pad * bw)
    y0, y1 = max(0.0, box[1] - pad * bh), min(1.0, box[3] + pad * bh)
    photo = image[top:top + h, left:left + w] * 255
    ys = y0 * (h - 1) + np.arange(out_size) * (y1 - y0) * (h - 1) / (out_size - 1)
    xs = x0 * (w - 1) + np.arange(out_size) * (x1 - x0) * (w - 1) / (out_size - 1)
    y_lo = np.floor(ys).astype(int)
    x_lo = np.floor(xs).astype(int)
    y_hi, x_hi = np.minimum(y_lo + 1, h - 1), np.minimum(x_lo + 1, w - 1)
    fy, fx = (ys - y_lo)[:, None, None], (xs - x_lo)[None, :, None]
    top_row = photo[y_lo][:, x_lo] * (1 - fx) + photo[y_lo][:, x_hi] * fx
    bottom_row = photo[y_hi][:, x_lo] * (1 - fx) + photo[y_hi][:, x_hi] * fx
    return (top_row * (1 - fy) + bottom_row * fy).astype(np.float32)


def collect(folder, models, classifier_path):
    """Per photo: its true classes, the detector's boxes and, for each meat
    box from 0.1 up, the classifier's probabilities of the meats (in MEATS
    order) and of khac."""
    classes = open(os.path.join(models, 'detector_classes.txt')).read().split()
    card = open(os.path.join(models, 'DETECTOR_CARD.md'), encoding='utf-8').read()
    meat_classes = open(os.path.join(models, 'meat_classes.txt')).read().split()
    meat_card = open(os.path.join(models, 'MEAT_CARD.md'), encoding='utf-8').read()
    pad = card_value(meat_card, 'crop_pad') or 0.1
    iou_limit = card_value(card, 'threshold_iou') or 0.5
    detector = tf.lite.Interpreter(os.path.join(models, 'detector.tflite'),
                                   num_threads=os.cpu_count())
    detector.allocate_tensors()
    size = int(detector.get_input_details()[0]['shape'][-1])
    meat = tf.lite.Interpreter(classifier_path, num_threads=os.cpu_count())
    meat.allocate_tensors()
    (m_in,), (m_out,) = meat.get_input_details(), meat.get_output_details()
    crop_size = int(m_in['shape'][1])
    meat_ids = [classes.index(c) for c in MEATS]
    # One cache per detector file.
    cache_path = os.path.join(folder, '.meat_eval_cache2_%d.npz' % os.path.getsize(
        os.path.join(models, 'detector.tflite')))
    cache = (dict(np.load(cache_path, allow_pickle=True))['boxes'].item()
             if os.path.exists(cache_path) else {})
    photos = []
    for path in sorted(glob.glob(os.path.join(folder, 'images', '*'))):
        name = os.path.basename(path)
        label = os.path.join(folder, 'labels', os.path.splitext(name)[0] + '.txt')
        truth = {int(line.split()[0]) for line in open(label) if line.strip()}
        image, place = letterbox(path, size)
        if name not in cache:
            cache[name] = detect(detector, image, place, len(classes), iou_limit,
                                 meat_ids)
        boxes = []
        for c, s, box, meat_scores in cache[name]:
            probs = None
            if c in meat_ids and s >= 0.1:
                meat.set_tensor(m_in['index'], crop(image, place, box, pad,
                                                    crop_size)[None])
                meat.invoke()
                p = meat.get_tensor(m_out['index'])[0]
                probs = (np.array([p[meat_classes.index(k)] for k in MEATS]),
                         float(p[meat_classes.index('khac')]))
            boxes.append((c, s, box, meat_scores, probs))
        photos.append((truth, boxes))
    np.savez(cache_path, boxes=np.array(cache, dtype=object))
    thresholds = [card_value(card, f'threshold_box_{c}') or
                  card_value(card, 'threshold_box') or 0.35 for c in classes]
    return photos, meat_ids, thresholds, iou_limit


def run(photos, thresholds, iou_limit, meat_ids, rename=None, fuse=None,
        floor=None, rescue=1.0, drop=None):
    """Found, foods, wrong over [photos] with the app's rules (§9.3). For a
    meat box from its class threshold up:
    - with [fuse], it takes the meat with the best detector score ** fuse
      times classifier probability (both models vote);
    - otherwise it takes the classifier's meat when that is another one at
      [rename] or more;
    - with [drop], it is dropped when the classifier says khac that sure.
    With [floor], a meat box between [floor] and its threshold is kept, as
    the classifier's meat, when the classifier is [rescue] sure of it (and,
    with [fuse], the vote agrees)."""
    hit = miss = wrong = 0
    for truth, boxes in photos:
        kept = []
        for c, s, box, meat_scores, probs in boxes:
            above = s >= thresholds[c]
            if probs is not None:
                meat_probs, other = probs
                k, p = meat_ids[int(meat_probs.argmax())], float(meat_probs.max())
                is_meat = p > other
                vote = (meat_ids[int((meat_scores ** fuse * meat_probs).argmax())]
                        if fuse is not None else k)
                if above:
                    if drop is not None and not is_meat and other >= drop:
                        continue
                    if fuse is not None:
                        c = vote
                    elif rename is not None and is_meat and k != c and p >= rename:
                        c = k
                elif (floor is not None and s >= floor and is_meat and
                      p >= rescue and vote == k):
                    c, above = k, True
            if above:
                kept.append((c, s, box))
        found = {c for c, _, _ in nms(kept, iou_limit)}
        hit += len(truth & found)
        miss += len(truth - found)
        wrong += len(found - truth)
    return hit, hit + miss, wrong


def show(tag, result):
    hit, total, wrong = result
    print(f'{tag:46} found {hit}/{total} = {hit / total:.1%}, wrong {wrong}')


def f1(result):
    hit, total, wrong = result
    return 2 * hit / (hit + total + wrong)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('test')
    parser.add_argument('--tune')
    parser.add_argument('--models', default=os.path.join(
        os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'models'))
    parser.add_argument('--classifier')
    args = parser.parse_args()
    classifier = args.classifier or os.path.join(args.models, 'meat_classifier.tflite')
    meat_card = open(os.path.join(args.models, 'MEAT_CARD.md'), encoding='utf-8').read()
    card = {key: card_value(meat_card, line) for key, line in CARD_LINES.items()}
    card['rescue'] = card['rescue'] or 1.0
    test, meat_ids, thresholds, iou_limit = collect(args.test, args.models,
                                                    classifier)
    rules = (thresholds, iou_limit, meat_ids)
    print(f'{len(test)} test photos')
    show('detector alone', run(test, *rules))
    show(f'with MEAT_CARD.md {card}', run(test, *rules, **card))
    for rename in (0.5, 0.6, 0.7, 0.8, 0.9):
        show(f'rename from {rename}', run(test, *rules, rename))
    for fuse in (0.5, 1, 2):
        show(f'vote, detector score ** {fuse}', run(test, *rules, fuse=fuse))
    if not args.tune:
        return
    tune, *_ = collect(args.tune, args.models, classifier)
    print(f'\nTuning on {len(tune)} photos of {args.tune}')
    tune_alone = run(tune, *rules)
    show('detector alone (tuning photos)', tune_alone)
    grid = []
    for rename, fuse, floor, rescue, drop in itertools.product(
            (0.5, 0.6, 0.7, 0.8, 0.9), (None, 0.5, 1, 2),
            (None, 0.1, 0.15, 0.2, 0.3), (0.6, 0.7, 0.8, 0.9), (None, 0.8, 0.9)):
        if (floor is None and rescue != 0.6) or (fuse is not None and rename != 0.5):
            continue   # settings that do nothing new
        setting = dict(rename=None if fuse else rename, fuse=fuse, floor=floor,
                       rescue=rescue if floor else None, drop=drop)
        grid.append((run(tune, *rules, **setting), setting))
    choices = (
        # More foods found and no more wrong finds than the detector alone:
        # the one to ship.
        ('most found, no more wrong', lambda r, s: r[2] <= tune_alone[2],
         lambda r: (r[0], -r[2])),
        ('best F1', lambda r, s: True, f1),
        ('renaming only', lambda r, s: s['floor'] is None and s['drop'] is None,
         f1),
    )
    for i, (name, keep, key) in enumerate(choices):
        result, setting = max(((r, s) for r, s in grid if keep(r, s)),
                              key=lambda g: key(g[0]))
        show(f'{name} on tuning photos', result)
        show(f'  {setting} on test', run(test, *rules, **setting))
        if i == 0:
            print('  MEAT_CARD.md lines:\n' + ''.join(
                f'  {CARD_LINES[k]}: {v}\n' for k, v in setting.items()
                if v is not None))


if __name__ == '__main__':
    main()
