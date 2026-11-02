"""Gemini against our offline plate detector, on the same photos and scored
the same way: for each photo, which of the 21 detector classes are on it.

    python tool/eval/gemini_compare.py --images <yolo dir> --model gemini-3.8-flash
    python tool/eval/gemini_compare.py --images <yolo dir> --model gemini-3.8-flash \\
        --detector <best.pt> --out report.md

`--images` is a YOLO folder (`images/*.jpg`, `labels/*.txt`) whose class ids
follow `assets/models/detector_classes.txt`. Every Gemini answer is cached
under `--cache` (one JSON file per photo), so a rerun only scores and costs
nothing; `--offline` never calls the API. The key is read from the
GEMINI_API_KEY environment variable, or on Windows from the user's saved
environment (so it works without restarting the shell). It is never printed
or written anywhere.

`--detector` also scores a YOLO `.pt` with the thresholds in
`assets/models/DETECTOR_CARD.md` (needs ultralytics), so both appear in one
table.
"""
import argparse
import base64
import glob
import hashlib
import io
import json
import os
import re
import statistics
import sys
import threading
import time
import urllib.error
import urllib.request
from collections import Counter
from concurrent.futures import ThreadPoolExecutor

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CLASSES = open(os.path.join(REPO, 'assets', 'models', 'detector_classes.txt'),
               encoding='utf-8').read().split()
OTHER = 'other'
ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/interactions'

# What each class means, in the words the detector was trained on
# (docs/MODEL_CONTRACT.md §7 and FIS_CLASS in tool/train/train_detector.py).
DESCRIPTIONS = {
    'com': ('cơm (cơm trắng, cơm tấm, cơm chiên)', 'cooked rice of any kind'),
    'bun': ('bún (sợi bún gạo tròn, trắng)', 'Vietnamese round rice vermicelli'),
    'mi': ('mì, phở, hủ tiếu, miến', 'noodles: wheat, flat rice or glass noodles'),
    'banh_mi_o': ('ổ bánh mì', 'Vietnamese baguette or bread roll'),
    'ga': ('thịt gà hoặc vịt (luộc, chiên, nướng, ức gà)',
           'chicken or duck meat, any cooking, including chicken breast'),
    'thit_kho': ('thịt heo kho (kho tàu, nước kho màu nâu)',
                 'Vietnamese braised caramelised pork'),
    'thit_nuong': ('thịt heo nướng, sườn nướng', 'grilled pork or grilled pork chop'),
    'heo': ('thịt heo khác (luộc, quay, xào, chiên, ba chỉ)',
            'other pork: boiled, roast, stir-fried, fried, belly'),
    'bo': ('thịt bò (bít tết, xào, nướng)', 'beef: steak, stir-fried, grilled'),
    'ca': ('cá (chiên, kho, hấp, nướng)', 'fish, any cooking'),
    'tom': ('tôm', 'shrimp or prawn'),
    'muc': ('mực', 'squid'),
    'trung': ('trứng (luộc, chiên, ốp la, trứng cuộn)',
              'egg: boiled, fried, omelette, rolled'),
    'dau_hu': ('đậu hũ', 'tofu'),
    'cha': ('chả lụa, giò, chả', 'Vietnamese pork roll or pork loaf (chả lụa)'),
    'cha_gio': ('chả giò, nem rán', 'fried spring roll'),
    'rau': ('rau: rau lá, rau cải, xà lách, bông cải, bắp cải, giá',
            'vegetables: leafy greens, bok choy, lettuce, broccoli, cabbage, bean sprouts'),
    'dua_leo_ca_chua': ('dưa leo, cà chua', 'cucumber or tomato'),
    'do_chua': ('đồ chua (cà rốt, củ cải ngâm chua)', 'pickled carrot and daikon'),
    'khoai_tay_chien': ('khoai tây chiên', 'french fries'),
    'canh': ('canh, súp (bát nước)', 'soup in a bowl'),
}
assert sorted(DESCRIPTIONS) == sorted(CLASSES), 'DESCRIPTIONS must cover detector_classes.txt'

PROMPT = '\n'.join([
    'You see one photo of a meal. List every food that is visible on it.',
    'For each food pick the one class below that fits it best. If no class fits'
    f' (for example carrot, corn, potato that is not fried, sauce, fruit), use "{OTHER}".',
    'List a class once per food item; two separate pieces of the same food are one item.',
    'Only list foods you can actually see; do not guess hidden ingredients.',
    'Also estimate the grams of each item as served.',
    '',
    'Classes (id: Vietnamese / English):',
    *[f'- {c}: {DESCRIPTIONS[c][0]} / {DESCRIPTIONS[c][1]}' for c in CLASSES],
    f'- {OTHER}: món khác / any other food',
])
SCHEMA = {
    'type': 'object',
    'properties': {
        'foods': {
            'type': 'array',
            'items': {
                'type': 'object',
                'properties': {
                    'class': {'type': 'string', 'enum': CLASSES + [OTHER]},
                    'name': {'type': 'string', 'description': 'what the food is, in a few words'},
                    'grams': {'type': 'number'},
                },
                'required': ['class', 'name', 'grams'],
            },
        },
    },
    'required': ['foods'],
}
PROMPT_TAG = hashlib.sha256((PROMPT + json.dumps(SCHEMA, sort_keys=True)).encode()).hexdigest()[:8]

# USD per 1M tokens, Standard tier, ai.google.dev/gemini-api/docs/pricing as
# read on 2026-11-02 (input text/image, output including thinking). Used only
# to say what the run would cost on a paid key; the free tier costs nothing.
PRICES = {
    'gemini-4-argon': (2.00, 10.00),
    'gemini-3.8-flash': (0.75, 3.75),
    'gemini-3.6-flash': (0.75, 3.75),
    'gemini-3.5-flash-lite': (0.30, 2.50),
    'gemini-3.1-flash-lite': (0.25, 1.50),
    'gemini-3-flash-preview': (0.50, 3.00),
}
MAX_SIDE = 1024


def api_key():
    key = os.environ.get('GEMINI_API_KEY') or os.environ.get('GOOGLE_API_KEY')
    if not key and sys.platform == 'win32':
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, 'Environment') as k:
            for name in ('GEMINI_API_KEY', 'GOOGLE_API_KEY'):
                try:
                    key = winreg.QueryValueEx(k, name)[0]
                    break
                except OSError:
                    pass
    if not key:
        sys.exit('GEMINI_API_KEY is not set')
    return key


def photo_bytes(path):
    """The JPEG as sent: the file itself, or shrunk to MAX_SIDE when larger."""
    data = open(path, 'rb').read()
    from PIL import Image
    im = Image.open(io.BytesIO(data))
    if max(im.size) <= MAX_SIDE:
        return data
    im = im.convert('RGB')
    im.thumbnail((MAX_SIDE, MAX_SIDE))
    out = io.BytesIO()
    im.save(out, 'JPEG', quality=90)
    return out.getvalue()


def answer_text(node):
    """The JSON text of a model answer, wherever the response keeps it."""
    if isinstance(node, dict):
        text = node.get('text')
        if isinstance(text, str) and '"foods"' in text:
            return text
        node = list(node.values())
    if isinstance(node, list):
        for item in node:
            found = answer_text(item)
            if found:
                return found
    return None


class QuotaExhausted(Exception):
    pass


class Caller:
    """Sends photos at most `rpm` a minute and retries rate-limit errors."""

    def __init__(self, model, thinking, rpm):
        self.model, self.thinking = model, thinking
        self.gap = 60.0 / rpm
        self.next_start = 0.0
        self.lock = threading.Lock()
        self.key = api_key()
        self.stop = False

    def wait_turn(self):
        with self.lock:
            now = time.monotonic()
            start = max(now, self.next_start)
            self.next_start = start + self.gap
        time.sleep(max(0.0, start - now))

    def ask(self, jpeg):
        config = {'seed': 0}
        if self.thinking:
            config['thinking_level'] = self.thinking
        body = json.dumps({
            'model': self.model,
            'input': [
                {'type': 'text', 'text': PROMPT},
                {'type': 'image', 'data': base64.b64encode(jpeg).decode(), 'mime_type': 'image/jpeg'},
            ],
            'response_format': {'type': 'text', 'mime_type': 'application/json', 'schema': SCHEMA},
            'generation_config': config,
            'store': False,
        }).encode()
        for attempt in range(10):
            if self.stop:
                raise QuotaExhausted('stopped')
            self.wait_turn()
            request = urllib.request.Request(ENDPOINT, data=body, method='POST', headers={
                'Content-Type': 'application/json', 'x-goog-api-key': self.key})
            started = time.monotonic()
            try:
                with urllib.request.urlopen(request, timeout=180) as r:
                    return json.loads(r.read()), time.monotonic() - started
            except urllib.error.HTTPError as e:
                detail = e.read().decode('utf-8', 'replace')
                print(f'  HTTP {e.code}: {" ".join(detail.split())[:200]}', file=sys.stderr, flush=True)
                if e.code == 429:
                    if re.search(r'per ?day|PerDay|daily', detail, re.I):
                        self.stop = True
                        raise QuotaExhausted(detail[:300])
                    delay = re.search(r'"retryDelay":\s*"(\d+)', detail)
                    time.sleep(int(delay.group(1)) + 1 if delay else 20 * (attempt + 1))
                elif e.code in (500, 502, 503, 504):
                    time.sleep(min(120, 15 * (attempt + 1)))
                else:
                    raise RuntimeError(f'HTTP {e.code}: {detail[:500]}')
            except (urllib.error.URLError, TimeoutError) as e:
                print(f'  network: {e}; retrying', file=sys.stderr)
                time.sleep(10 * (attempt + 1))
        raise RuntimeError('gave up after 10 tries')


def load_truth(root):
    images = sorted(glob.glob(os.path.join(root, 'images', '*.jpg')))
    truth = {}
    for p in images:
        stem = os.path.splitext(os.path.basename(p))[0]
        with open(os.path.join(root, 'labels', stem + '.txt')) as f:
            truth[stem] = {CLASSES[int(l.split()[0])] for l in f if l.strip()}
    return images, truth


def run_gemini(images, model, args):
    folder = os.path.join(args.cache, f'{model}__{args.thinking or "default"}__p{PROMPT_TAG}')
    os.makedirs(folder, exist_ok=True)
    todo = [p for p in images
            if not os.path.exists(os.path.join(folder, os.path.splitext(os.path.basename(p))[0] + '.json'))]
    if args.limit:
        todo = todo[:args.limit]
    if todo and not args.offline:
        caller = Caller(model, args.thinking, args.rpm)
        done = Counter()

        def one(path):
            stem = os.path.splitext(os.path.basename(path))[0]
            try:
                response, seconds = caller.ask(photo_bytes(path))
            except QuotaExhausted:
                done['quota'] += 1
                return
            except Exception as e:
                done['error'] += 1
                print(f'  {stem}: {e}', file=sys.stderr)
                return
            with open(os.path.join(folder, stem + '.json'), 'w', encoding='utf-8') as f:
                json.dump({'seconds': seconds, 'response': response}, f, ensure_ascii=False)
            done['ok'] += 1
            if done['ok'] % 25 == 0:
                print(f'  {model}: {done["ok"]}/{len(todo)} new answers', file=sys.stderr, flush=True)

        print(f'{model}: asking for {len(todo)} photos at {args.rpm}/min', file=sys.stderr)
        with ThreadPoolExecutor(args.workers) as pool:
            list(pool.map(one, todo))
        if done['quota']:
            print(f'  daily quota reached; {done["quota"]} photos left for the next run', file=sys.stderr)
        if done['error']:
            print(f'  {done["error"]} photos failed (not cached)', file=sys.stderr)

    found, usage, seconds, others, unreadable = {}, Counter(), [], Counter(), 0
    for p in images:
        stem = os.path.splitext(os.path.basename(p))[0]
        path = os.path.join(folder, stem + '.json')
        if not os.path.exists(path):
            continue
        saved = json.load(open(path, encoding='utf-8'))
        seconds.append(saved['seconds'])
        u = saved['response'].get('usage') or {}
        usage['input'] += u.get('total_input_tokens', 0)
        usage['output'] += u.get('total_output_tokens', 0)
        usage['thought'] += u.get('total_thought_tokens', 0)
        usage['calls'] += 1
        text = answer_text(saved['response'])
        try:
            foods = json.loads(text)['foods'] if text else []
        except (ValueError, KeyError, TypeError):
            foods = []
        if not text:
            unreadable += 1
        found[stem] = {f.get('class') for f in foods if f.get('class') in CLASSES}
        for f in foods:
            if f.get('class') == OTHER:
                others[str(f.get('name', '')).lower()] += 1
    return found, {'usage': usage, 'seconds': seconds, 'others': others, 'unreadable': unreadable}


def card_thresholds():
    card = open(os.path.join(REPO, 'assets', 'models', 'DETECTOR_CARD.md'), encoding='utf-8').read()
    base = float(re.search(r'^threshold_box:\s*([\d.]+)', card, re.M).group(1))
    own = {m.group(1): float(m.group(2)) for m in re.finditer(r'^threshold_box_(\w+):\s*([\d.]+)', card, re.M)}
    iou = float(re.search(r'^threshold_iou:\s*([\d.]+)', card, re.M).group(1))
    return {c: own.get(c, base) for c in CLASSES}, iou


def run_detector(images, weights, cache):
    """Best score of each class on each photo, cached by the weights' hash."""
    tag = hashlib.sha256(open(weights, 'rb').read()).hexdigest()[:12]
    path = os.path.join(cache, f'detector_{tag}.json')
    thresholds, iou = card_thresholds()
    if os.path.exists(path):
        top = json.load(open(path))
    else:
        from ultralytics import YOLO
        model, top, started = YOLO(weights), {}, time.monotonic()
        for i in range(0, len(images), 16):
            batch = images[i:i + 16]
            for p, r in zip(batch, model.predict(batch, imgsz=512, conf=0.05, iou=iou, verbose=False, device='cpu')):
                best = {}
                for c, s in zip(r.boxes.cls.tolist(), r.boxes.conf.tolist()):
                    best[CLASSES[int(c)]] = max(best.get(CLASSES[int(c)], 0.0), s)
                top[os.path.splitext(os.path.basename(p))[0]] = best
        top['_seconds'] = (time.monotonic() - started) / len(images)
        with open(path, 'w') as f:
            json.dump(top, f)
    seconds = top.pop('_seconds', None)
    return top, thresholds, seconds


def detector_found(top, thresholds, scale=1.0):
    return {stem: {c for c, s in best.items() if s >= thresholds[c] * scale} for stem, best in top.items()}


def matching_scale(top, thresholds, truth, wrong_target):
    """The largest scale of all card thresholds at which the detector makes at
    least `wrong_target` wrong finds, so it can be compared at Gemini's
    wrong-find rate as well as at its own."""
    for step in range(100, 9, -1):
        if sum(score(detector_found(top, thresholds, step / 100), truth)[2].values()) >= wrong_target:
            return step / 100
    return 0.1


PORK = {'heo', 'thit_kho', 'thit_nuong'}


def merge_pork(classes):
    return {('heo' if c in PORK else c) for c in classes}


def score(found, truth, lenient=False):
    hit, n, wrong = Counter(), Counter(), Counter()
    for stem, t in truth.items():
        if stem not in found:
            continue
        f = found[stem]
        if lenient:
            t, f = merge_pork(t), merge_pork(f)
        for c in t:
            n[c] += 1
            hit[c] += c in f
        for c in f - t:
            wrong[c] += 1
    return hit, n, wrong


def summary_line(name, found, truth, extra=''):
    hit, n, wrong = score(found, truth)
    lh, ln, lw = score(found, truth, lenient=True)
    photos = sum(s in found for s in truth)
    return (f'| {name} | {photos} | {sum(hit.values())}/{sum(n.values())} = '
            f'{sum(hit.values()) / max(1, sum(n.values())):.1%} | {sum(wrong.values())} '
            f'({sum(wrong.values()) / max(1, photos):.2f}) | {hit["ga"]}/{n["ga"]} | '
            f'{sum(lh.values()) / max(1, sum(ln.values())):.1%}, {sum(lw.values())} |{extra}')


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--images', required=True)
    ap.add_argument('--model', action='append', default=[], help='Gemini model id; repeat for several')
    ap.add_argument('--thinking', help='thinking_level (minimal, low, medium, high); default: the model\'s own')
    ap.add_argument('--detector', help='YOLO .pt to score with DETECTOR_CARD.md thresholds')
    ap.add_argument('--cache', default=r'D:\Temp\macrorunner_gemini_cache')
    ap.add_argument('--rpm', type=float, default=8, help='requests a minute (free tier limits: see AI Studio)')
    ap.add_argument('--workers', type=int, default=4)
    ap.add_argument('--limit', type=int, help='ask for at most this many new photos')
    ap.add_argument('--offline', action='store_true', help='only score cached answers')
    ap.add_argument('--out', help='also write the report (markdown) here')
    args = ap.parse_args()

    images, truth = load_truth(args.images)
    os.makedirs(args.cache, exist_ok=True)
    rows, results = [], {}
    if args.detector:
        top, thresholds, sec = run_detector(images, args.detector, args.cache)
        det = detector_found(top, thresholds)
        results['detector (.pt)'] = det
        rows.append(summary_line('detector .pt, card thresholds', det, truth,
                                 f' {sec:.2f} s (PC CPU) | 0 |' if sec else ' | 0 |'))
    for model in args.model:
        found, info = run_gemini(images, model, args)
        results[model] = found
        u = info['usage']
        price = PRICES.get(model)
        cost = (u['input'] * price[0] + (u['output'] + u['thought']) * price[1]) / 1e6 if price else float('nan')
        sec = info['seconds']
        rows.append(summary_line(
            model + (f' ({args.thinking})' if args.thinking else ''), found, truth,
            f' {statistics.median(sec):.1f} s (median), {statistics.mean(sec):.1f} s (mean) |'
            f' {u["calls"]} calls, {u["input"]:,} in + {u["output"]:,} out + {u["thought"]:,} thinking tokens,'
            f' ${cost:.2f} on a paid key |' if sec else ' | 0 |'))
        if info['unreadable']:
            rows.append(f'|   {info["unreadable"]} answers had no readable JSON (scored as nothing found) |')
        results[model + ' other'] = info['others']
        if args.detector and len(found) == len(truth):
            wrong = sum(score(found, truth)[2].values())
            scale = matching_scale(top, thresholds, truth, wrong)
            matched = detector_found(top, thresholds, scale)
            results[f'detector ×{scale:.2f}'] = matched
            rows.append(summary_line(f'detector .pt, card thresholds ×{scale:.2f} (wrong ≈ {model})',
                                     matched, truth, ' | 0 |'))

    out = [f'{len(images)} photos, {sum(len(t) for t in truth.values())} foods on them; prompt {PROMPT_TAG}.', '',
           '| who | photos | found | wrong (a photo) | chicken | pork merged: found, wrong | seconds a photo | calls, tokens, cost |',
           '|---|---|---|---|---|---|---|---|', *rows, '']
    names = [k for k in results if not k.endswith(' other')]
    present = sorted({c for t in truth.values() for c in t}, key=CLASSES.index)
    absent = [c for c in CLASSES if c not in present]
    out += ['Per class, found/on photos (wrong):', '',
            '| class | ' + ' | '.join(names) + ' |', '|---' * (len(names) + 1) + '|']
    scored = {k: score(results[k], truth) for k in names}
    for c in present + absent:
        cells = []
        for k in names:
            hit, n, wrong = scored[k]
            cells.append(f'{hit[c]}/{n[c]} ({wrong[c]})' if n[c] else f'– ({wrong[c]})')
        out.append(f'| {c} | ' + ' | '.join(cells) + ' |')
    for k in results:
        if k.endswith(' other') and results[k]:
            out += ['', f'{k[:-6]} put under "other": ' + ', '.join(f'{name} {n}' for name, n in results[k].most_common(15))]
    report = '\n'.join(out)
    print(report)
    if args.out:
        with open(args.out, 'w', encoding='utf-8') as f:
            f.write(report + '\n')


if __name__ == '__main__':
    main()
