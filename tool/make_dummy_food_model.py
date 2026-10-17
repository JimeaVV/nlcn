"""Builds an untrained food model that follows docs/MODEL_CONTRACT.md §6.

It exists to test the app's model path end to end on a phone before the
real model is trained, and to show the exact export format. Its guesses are
random, so never ship it in assets/models/.

Needs TensorFlow (any 2.x with tf.keras). From the project root:
    python tool/make_dummy_food_model.py build/dummy_model
"""
import csv
import re
import sys
from pathlib import Path

import tensorflow as tf

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / 'assets' / 'data' / 'vn_food'
CONTRACT = ROOT / 'docs' / 'MODEL_CONTRACT.md'


def contract_components():
    """Component codes in the order of the contract's §3 table."""
    text = CONTRACT.read_text(encoding='utf-8')
    section = re.search(r'^## 3\..*?(?=^## )', text, re.M | re.S).group(0)
    return [m.group(1) for m in re.finditer(r'^\|[^|]*\|\s*`([a-z0-9_]+)`', section, re.M)]


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else ROOT / 'build' / 'dummy_model')
    out.mkdir(parents=True, exist_ok=True)
    with (DATA / 'dish_names.csv').open(encoding='utf-8', newline='') as file:
        dishes = [row['code'] for row in csv.DictReader(file)]
    components = contract_components()

    tf.keras.utils.set_random_seed(0)
    # Raw RGB 0-255 in; normalisation belongs inside the model.
    image = tf.keras.Input(shape=(224, 224, 3), dtype='float32', name='image')
    x = tf.keras.layers.Rescaling(1 / 127.5, offset=-1)(image)
    x = tf.keras.layers.AveragePooling2D(8)(x)
    x = tf.keras.layers.Conv2D(16, 3, activation='relu')(x)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    dish = tf.keras.layers.Dense(len(dishes), activation='softmax', name='dish')(x)
    parts = tf.keras.layers.Dense(len(components), activation='sigmoid', name='components')(x)
    model = tf.keras.Model(image, [dish, parts])

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]
    (out / 'food_v1.tflite').write_bytes(converter.convert())
    (out / 'dishes.txt').write_text('\n'.join(dishes) + '\n', encoding='utf-8')
    (out / 'components.txt').write_text('\n'.join(components) + '\n', encoding='utf-8')
    (out / 'MODEL_CARD.md').write_text(
        '# MODEL GIẢ – KHÔNG DÙNG THẬT\n\n'
        'Model chưa train, đoán ngẫu nhiên; chỉ để thử luồng chạy model trong app.\n\n'
        f'- Số món: {len(dishes)}, số thành phần: {len(components)}\n'
        '- threshold_checked: 0.6\n- threshold_ask: 0.3\n- threshold_confident_dish: 0.5\n',
        encoding='utf-8')
    print(f'Wrote {out} ({len(dishes)} dishes, {len(components)} components)')


if __name__ == '__main__':
    main()
