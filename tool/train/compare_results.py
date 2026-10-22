"""Compares training runs and picks the model the app ships.

Each argument is a run's output folder (results.json, training logs,
food_v1.tflite), as downloaded from Kaggle or Google Drive:
    python tool/train/compare_results.py runs/mobilenetv3 runs/efficientnetb0 ...

The winner has the best dish top-1 on the validation set. The test set is
only reported, so choosing among backbones does not tune on it. Runs within
TIE of the best count as equal, and the smaller model wins, since it loads
and runs faster on the phone. Quick tests are left out.
"""
import argparse
import csv
import json
import os
import sys

TIE = 0.005   # 0.5 percentage point of validation top-1


def val_from_logs(folder):
    """Validation top-1 of the kept weights, for runs made before
    results.json recorded it: the best epoch of the last training phase
    (early stopping restores that epoch)."""
    for phase in ('fine', 'scratch', 'head'):
        path = os.path.join(folder, f'training_log_{phase}.csv')
        if os.path.exists(path):
            with open(path, newline='') as f:
                values = [float(row['val_dish_accuracy'])
                          for row in csv.DictReader(f)
                          if row.get('val_dish_accuracy')]
            if values:
                return max(values)
    return None


def load(folder):
    with open(os.path.join(folder, 'results.json'), encoding='utf-8') as f:
        run = json.load(f)
    run['folder'] = folder
    if run.get('val_dish_top1') is None:
        run['val_dish_top1'] = val_from_logs(folder)
        run['val_from_logs'] = True
    model = os.path.join(folder, 'food_v1.tflite')
    if run.get('tflite_mb') is None and os.path.exists(model):
        run['tflite_mb'] = round(os.path.getsize(model) / 1e6, 2)
    return run


def pick(runs):
    usable = [r for r in runs if r.get('val_dish_top1') is not None]
    if not usable:
        return None
    best = max(r['val_dish_top1'] for r in usable)
    close = [r for r in usable if best - r['val_dish_top1'] <= TIE]
    return min(close, key=lambda r: (r.get('tflite_mb') or float('inf'),
                                     -r['val_dish_top1']))


def percent(value):
    return '–' if value is None else f'{value * 100:.1f}%'


def number(value, unit=''):
    return '–' if value is None else f'{value}{unit}'


def table(runs, winner):
    lines = [
        '| Backbone | Thí nghiệm | Val top-1 | Test top-1 | Test top-3 | '
        'Thành phần F1 | TFLite | CPU / ảnh | Train |',
        '|---|---|---|---|---|---|---|---|---|',
    ]
    for r in sorted(runs, key=lambda r: -(r.get('val_dish_top1') or 0)):
        name = r['backbone'] + (' **(chọn)**' if r is winner else '')
        val = percent(r.get('val_dish_top1'))
        if r.get('val_from_logs'):
            val += '¹'
        f1 = r.get('component_f1')
        lines.append(
            f"| {name} | {r['experiment']} | {val} | "
            f"{percent(r.get('dish_top1'))} | {percent(r.get('dish_top3'))} | "
            f"{'–' if f1 is None else f'{f1:.3f}'} | "
            f"{number(r.get('tflite_mb'), ' MB')} | "
            f"{number(r.get('cpu_ms'), ' ms')} | "
            f"{number(r.get('train_minutes'), ' phút')} |")
    if any(r.get('val_from_logs') for r in runs):
        lines.append('')
        lines.append('¹ Lấy từ `training_log_*.csv` (epoch tốt nhất của pha '
                     'cuối), vì bản chạy này chưa ghi val vào results.json.')
    return '\n'.join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('folders', nargs='+')
    parser.add_argument('--out', help='also write the table to this file')
    args = parser.parse_args(argv)

    runs = [load(folder) for folder in args.folders]
    quick = [r for r in runs if r.get('quick_test')]
    runs = [r for r in runs if not r.get('quick_test')]
    for r in quick:
        print(f"Bỏ qua {r['folder']}: bản chạy thử (QUICK_TEST).")
    if not runs:
        print('Không có bản train thật nào để so.')
        return 1
    contracts = {(r['photos']['val'], r['photos']['test']) for r in runs}
    if len(contracts) > 1:
        print('Cảnh báo: số ảnh val/test khác nhau giữa các bản chạy, '
              'nên chúng không dùng chung một cách chia dữ liệu.')

    winner = pick(runs)
    text = table(runs, winner)
    if winner is not None:
        text += (f"\n\nChọn **{winner['backbone']}** ({winner['folder']}): "
                 f"val top-1 cao nhất, hoặc ngang (lệch ≤ {TIE * 100:.1f} điểm %) "
                 'mà file nhỏ hơn.')
    print(text)
    if args.out:
        with open(args.out, 'w', encoding='utf-8') as f:
            f.write(text + '\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
