"""Builds train_food_model.ipynb from train_food_model.py.

The .py file is the source (readable diffs in git); cells start with
`# %%`, markdown cells with `# %% [markdown]`. Run after editing it:
    python tool/train/make_notebook.py
Another source in this folder, e.g. evaluate_tta.py, is passed by name:
    python tool/train/make_notebook.py evaluate_tta.py
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SOURCE = HERE / (sys.argv[1] if len(sys.argv) > 1 else 'train_food_model.py')
TARGET = SOURCE.with_suffix('.ipynb')


def cells(text):
    blocks, current = [], None
    for line in text.splitlines(keepends=True):
        if line.startswith('# %%'):
            current = {'markdown': '[markdown]' in line, 'lines': []}
            blocks.append(current)
        elif current is not None:
            current['lines'].append(line)
    for block in blocks:
        lines = block['lines']
        while lines and not lines[-1].strip():
            lines.pop()
        if block['markdown']:
            lines = [l[2:] if l.startswith('# ') else l.lstrip('#') for l in lines]
            yield {'cell_type': 'markdown', 'metadata': {}, 'source': lines}
        else:
            yield {'cell_type': 'code', 'metadata': {}, 'execution_count': None,
                   'outputs': [], 'source': lines}


notebook = {
    'cells': list(cells(SOURCE.read_text(encoding='utf-8'))),
    'metadata': {
        'kernelspec': {'name': 'python3', 'display_name': 'Python 3',
                       'language': 'python'},
        'language_info': {'name': 'python'},
    },
    'nbformat': 4,
    'nbformat_minor': 5,
}
TARGET.write_text(json.dumps(notebook, ensure_ascii=False, indent=1) + '\n',
                  encoding='utf-8')
print(f'Wrote {TARGET.name} with {len(notebook["cells"])} cells')
