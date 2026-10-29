"""Stores the float32 weights of a TFLite model as float16, each behind a
DEQUANTIZE op that turns it back to float32 when the model is loaded: what
the TensorFlow converter does for float16, but applied to a file it did not
make. The graph, input and output stay the same."""
import sys
import numpy as np
from tensorflow.lite.python import schema_py_generated as s
from tensorflow.lite.tools import flatbuffer_utils as fu

src, dst = sys.argv[1], sys.argv[2]
m = fu.read_model(src)
assert len(m.subgraphs) == 1, len(m.subgraphs)
assert all(not b.offset for b in m.buffers), 'buffers stored outside the flatbuffer'
g = m.subgraphs[0]
code = s.BuiltinOperator.DEQUANTIZE
deq = next((i for i, c in enumerate(m.operatorCodes)
            if max(c.builtinCode, c.deprecatedBuiltinCode) == code), None)
if deq is None:
    c = s.OperatorCodeT()
    c.builtinCode = c.deprecatedBuiltinCode = code
    c.version = 2
    m.operatorCodes.append(c)
    deq = len(m.operatorCodes) - 1
used = {i for op in g.operators for i in op.inputs if i >= 0}
added, before, after = [], 0, 0
for i in sorted(used):
    t = g.tensors[i]
    data = m.buffers[t.buffer].data if t.buffer else None
    if t.type != s.TensorType.FLOAT32 or data is None or len(data) == 0:
        continue
    w = np.frombuffer(bytes(bytearray(data)), dtype=np.float32)
    assert np.abs(w).max() < 65000, (t.name, np.abs(w).max())
    b = s.BufferT()
    b.data = np.frombuffer(w.astype(np.float16).tobytes(), dtype=np.uint8)
    m.buffers.append(b)
    h = s.TensorT()
    h.shape, h.type, h.buffer = t.shape, s.TensorType.FLOAT16, len(m.buffers) - 1
    h.name = (t.name or b'w') + b'_fp16' if isinstance(t.name, bytes) else f'{t.name}_fp16'
    g.tensors.append(h)
    m.buffers[t.buffer].data = None
    op = s.OperatorT()
    op.opcodeIndex, op.inputs, op.outputs = deq, [len(g.tensors) - 1], [i]
    added.append(op)
    before += w.nbytes; after += w.nbytes // 2
g.operators = added + g.operators
fu.write_model(m, dst)
print(f'{len(added)} weight tensors to float16: {before/1e6:.1f} MB -> {after/1e6:.1f} MB')
