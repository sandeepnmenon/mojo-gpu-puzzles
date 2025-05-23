from gpu.host import DeviceContext
from sys import sizeof, argv
from testing import assert_equal

# ANCHOR: prefix_sum_simple
from gpu import thread_idx, block_idx, block_dim, barrier
from layout import Layout, LayoutTensor
from layout.tensor_builder import LayoutTensorBuild as tb
from math import log2


alias TPB = 8
alias SIZE = 8
alias BLOCKS_PER_GRID = (1, 1)
alias THREADS_PER_BLOCK = (TPB, 1)
alias dtype = DType.float32
alias layout = Layout.row_major(SIZE)


fn prefix_sum_simple[
    layout: Layout
](
    out: LayoutTensor[mut=False, dtype, layout],
    a: LayoutTensor[mut=False, dtype, layout],
    size: Int,
):
    global_i = block_dim.x * block_idx.x + thread_idx.x
    local_i = thread_idx.x
    # FILL ME IN (roughly 12 lines)


# ANCHOR_END: prefix_sum_simple


# ANCHOR: prefix_sum_complete
alias SIZE_2 = 15
alias BLOCKS_PER_GRID_2 = (2, 1)
alias THREADS_PER_BLOCK_2 = (TPB, 1)


fn prefix_sum[
    layout: Layout
](
    out: LayoutTensor[mut=False, dtype, layout],
    a: LayoutTensor[mut=False, dtype, layout],
    size: Int,
):
    global_i = block_dim.x * block_idx.x + thread_idx.x
    local_i = thread_idx.x
    # FILL ME IN (roughly 19 lines)


# ANCHOR_END: prefix_sum_complete


def main():
    with DeviceContext() as ctx:
        out = ctx.enqueue_create_buffer[dtype](SIZE).enqueue_fill(0)
        a = ctx.enqueue_create_buffer[dtype](SIZE).enqueue_fill(0)
        with a.map_to_host() as a_host:
            for i in range(SIZE):
                a_host[i] = i

        out_tensor = LayoutTensor[mut=False, dtype, layout](out.unsafe_ptr())
        a_tensor = LayoutTensor[mut=False, dtype, layout](a.unsafe_ptr())

        if argv()[1] == "--simple":
            ctx.enqueue_function[prefix_sum_simple[layout]](
                out_tensor,
                a_tensor,
                SIZE,
                grid_dim=BLOCKS_PER_GRID,
                block_dim=THREADS_PER_BLOCK,
            )
        elif argv()[1] == "--complete":
            ctx.enqueue_function[prefix_sum[layout]](
                out_tensor,
                a_tensor,
                SIZE,
                grid_dim=BLOCKS_PER_GRID_2,
                block_dim=THREADS_PER_BLOCK_2,
            )
        else:
            raise Error("Invalid argument")

        expected = ctx.enqueue_create_host_buffer[dtype](SIZE).enqueue_fill(0)

        ctx.synchronize()

        with a.map_to_host() as a_host:
            expected[0] = a_host[0]
            for i in range(1, SIZE):
                expected[i] = expected[i - 1] + a_host[i]

        with out.map_to_host() as out_host:
            print("out:", out)
            print("expected:", expected)
            for i in range(SIZE):
                assert_equal(out_host[i], expected[i])
