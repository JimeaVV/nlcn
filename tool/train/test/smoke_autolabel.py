"""Runs autolabel_detector.py end to end on a few fake photos, on the CPU,
and checks what it leaves behind. Use it after every change to
autolabel_detector.py, before sending the notebook to Colab.

    python tool/train/test/smoke_autolabel.py

Needs a Python with ultralytics 8.4 and transformers 4.5x. Downloads
Grounding DINO once (about 900 MB, kept in the Hugging Face cache); set
GD_MODEL=IDEA-Research/grounding-dino-tiny for a smaller one. The checker is
an untrained YOLO11n with the 21 classes. Takes 2–4 minutes; the photos are
drawn shapes, so what Grounding DINO finds on them says nothing about
quality: this checks the plumbing (folders to dishes, duplicates, Open
Images rows, the zip, the card).
"""
import os
import subprocess
import sys
import tempfile
import zipfile

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
NOTEBOOK = os.path.join(HERE, '..', 'autolabel_detector.py')
CLASSES = [
    'com', 'bun', 'mi', 'banh_mi_o', 'ga', 'thit_kho', 'thit_nuong', 'heo',
    'bo', 'ca', 'tom', 'muc', 'trung', 'dau_hu', 'cha', 'cha_gio', 'rau',
    'dua_leo_ca_chua', 'do_chua', 'khoai_tay_chien', 'canh',
]


def plate(path, colours, shift=0):
    im = Image.new('RGB', (400, 300), (70, 60, 50 + shift))
    draw = ImageDraw.Draw(im)
    draw.ellipse((20, 20, 380, 280), fill=(235, 235, 235))
    for i, colour in enumerate(colours):
        draw.ellipse((60 + 110 * i + shift, 90, 150 + 110 * i + shift, 200),
                     fill=colour)
    im.save(path)


def make(root):
    dishes = os.path.join(root, 'input', 'vietnamese-foods', 'Images')
    for folder, colours in (('Train/Com tam', [(250, 250, 245), (150, 80, 40)]),
                            ('Test/Ca kho to', [(120, 70, 30)]),
                            ('Train/Pho', [(230, 220, 200)])):   # not used
        os.makedirs(os.path.join(dishes, folder), exist_ok=True)
        for i in range(2):
            plate(os.path.join(dishes, folder, f'{i}.jpg'), colours, shift=10 * i)
    # The same photo again under another dataset: boxed once.
    other = os.path.join(root, 'input', 'vinafood21', 'train', 'thit_kho_trung')
    os.makedirs(other, exist_ok=True)
    plate(os.path.join(other, 'a.jpg'), [(150, 80, 40), (250, 200, 40)])
    with open(os.path.join(other, 'a.jpg'), 'rb') as f, \
            open(os.path.join(other, 'b.jpg'), 'wb') as g:
        g.write(f.read())
    # Open Images rows: fries on a plate (kept), shrimp with no plate or
    # bowl (left out), and a drawing of fries (left out).
    oi = os.path.join(root, 'work', 'open_images')
    os.makedirs(os.path.join(oi, 'train'), exist_ok=True)
    rows = ['ImageID,Source,LabelName,Confidence,XMin,XMax,YMin,YMax,'
            'IsOccluded,IsTruncated,IsGroupOf,IsDepiction,IsInside']
    for image, label, box, drawn in (
            ('fries1', '/m/02y6n', (0.2, 0.6, 0.3, 0.7), 0),
            ('fries1', '/m/050gv4', (0.05, 0.95, 0.05, 0.95), 0),
            ('shrimp1', '/m/0ll1f78', (0.3, 0.5, 0.3, 0.5), 0),
            ('drawn1', '/m/02y6n', (0.2, 0.6, 0.3, 0.7), 1),
            ('drawn1', '/m/04kkgm', (0.1, 0.9, 0.1, 0.9), 0)):
        rows.append(f'{image},xclick,{label},1,{box[0]},{box[1]},{box[2]},{box[3]},'
                    f'0,0,0,{drawn},0')
        plate(os.path.join(oi, 'train', image + '.jpg'), [(240, 200, 60)])
    with open(os.path.join(oi, 'train-boxes.csv'), 'w') as f:
        f.write('\n'.join(rows) + '\n')
    # An untrained checker with the detector's classes.
    from ultralytics import YOLO
    teacher = YOLO('yolo11n.yaml')
    teacher.model.names = dict(enumerate(CLASSES))
    teacher.save(os.path.join(root, 'teacher.pt'))


def main():
    work = tempfile.mkdtemp(prefix='autolabel_smoke_')
    print('work folder', work)
    make(work)
    log = os.path.join(work, 'run.log')
    env = {**os.environ, 'PYTHONIOENCODING': 'utf-8',
           'INPUT_ROOT': os.path.join(work, 'input'),
           'OUTPUT_DIR': os.path.join(work, 'output'),
           'WORK_DIR': os.path.join(work, 'work'),
           'TEACHER_FROM': os.path.join(work, 'teacher.pt'),
           'DOWNLOAD_OPEN_IMAGES': '0'}
    with open(log, 'w', encoding='utf-8') as f:
        code = subprocess.run([sys.executable, NOTEBOOK], stdout=f,
                              stderr=subprocess.STDOUT, cwd=work, env=env).returncode
    with open(log, encoding='utf-8') as f:
        text = f.read()
    if code:
        print(text[-4000:])
        sys.exit(f'smoke_autolabel: run failed, log {log}')
    assert 'com_tam: 2 photos, 2 to box' in text, text[-2000:]
    assert 'ca_kho: 2 photos, 2 to box' in text, text[-2000:]
    assert 'pho:' not in text, 'phở photos were boxed'
    assert '5 dish photos to box (1 duplicates skipped)' in text, text[-2000:]
    assert 'khoai_tay_chien on 1 table photos' in text, text[-2000:]
    assert 'tom on' not in text, 'shrimp photo with no plate was taken'
    assert 'Open Images: 1 photos' in text, text[-2000:]
    output = os.path.join(work, 'output')
    with zipfile.ZipFile(os.path.join(output, 'autolabel.zip')) as z:
        names = z.namelist()
        assert 'sources.csv' in names, names
        sources = z.read('sources.csv').decode('utf-8').splitlines()
    images = [n for n in names if n.startswith('images/train/')]
    labels = [n for n in names if n.startswith('labels/train/')]
    assert len(images) == len(labels) == len(sources) - 1, (names, sources)
    with open(os.path.join(output, 'AUTOLABEL_CARD.md'), encoding='utf-8') as f:
        card = f.read()
    assert '| com_tam | 2 |' in card and '| thit_kho_trung | 1 |' in card, card
    print(card)
    print(f'smoke_autolabel: OK ({len(images)} photos kept)')


if __name__ == '__main__':
    main()
