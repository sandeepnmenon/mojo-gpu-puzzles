# Complete version: Block Boundary Case

## Configuration
- Input array size: `SIZE_2 = 15` elements
- Kernel size: `CONV_2 = 4` elements
- Threads per block: `TPB = 8`
- Number of blocks: 2
- Shared memory: `TPB + CONV_2 - 1` elements for input

Notes:
- **Extended loading**: Account for boundary overlap
- **Block edges**: Handle data across block boundaries
- **Memory layout**: Efficient shared memory usage
- **Synchronization**: Proper thread coordination

## Code to complete

```mojo
{{#include ../../../problems/p11/p11.mojo:conv_1d_block_boundary}}
```
<a href="{{#include ../_includes/repo_url.md}}/blob/main/problems/p11/p11.mojo" class="filename">View full file: problems/p11/p11.mojo</a>

<details>
<summary><strong>Tips</strong></summary>

<div class="solution-tips">

1. Use `tb[dtype]().row_major[TPB + CONV_2 - 1]().shared().alloc()` for shared memory
2. Load main data: `shared_a[local_i] = a[global_i]`
3. Load boundary: `if local_i < CONV_2 - 1` handle next block data
4. Load kernel: `shared_b[local_i] = b[local_i]`
5. Sum within extended bounds: `if local_i + j < TPB + CONV_2 - 1`
</div>
</details>

### Running the code

To test your solution, run the following command in your terminal:

```bash
magic run p11 --block-boundary
```

Your output will look like this if the puzzle isn't solved yet:
```txt
out: HostBuffer([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
expected: HostBuffer([5.0, 8.0, 11.0, 14.0, 5.0, 0.0])
```

## Solution

<details class="solution-details">
<summary></summary>

```mojo
{{#include ../../../solutions/p11/p11.mojo:conv_1d_block_boundary_solution}}
```

<div class="solution-explanation">

The solution handles block boundary cases in 1D convolution using extended shared memory. Here's a detailed analysis:

### Memory Layout and Sizing
```txt
Test Configuration:
- Full array size: SIZE_2 = 15 elements
- Grid: 2 blocks × 8 threads
- Convolution kernel: CONV_2 = 4 elements

Block 0 shared memory:  [0 1 2 3 4 5 6 7|8 9 10]  // TPB(8) + (CONV_2-1)(3) padding
Block 1 shared memory:  [8 9 10 11 12 13 14|0 0]  // Second block with padding

Size calculation:
- Main data: TPB elements (8)
- Overlap: CONV_2 - 1 elements (4 - 1 = 3)
- Total: TPB + CONV_2 - 1 = 8 + 4 - 1 = 11 elements
```

### Implementation Details

1. **Shared Memory Allocation**:
   ```mojo
   # First: account for padding needed for convolution window
   shared_a = tb[dtype]().row_major[TPB + CONV_2 - 1]().shared().alloc()
   shared_b = tb[dtype]().row_major[CONV_2]().shared().alloc()
   ```
   This allocation pattern ensures we have enough space for both the block's data and the overlap region.

2. **Data Loading Strategy**:
   ```mojo
   # Main block data
   if global_i < a_size:
       shared_a[local_i] = a[global_i]

   # Boundary data from next block
   if local_i < CONV_2 - 1:
       next_idx = global_i + TPB
       if next_idx < a_size:
           shared_a[TPB + local_i] = a[next_idx]
   ```
   - Only threads with `local_i < CONV_2 - 1` load boundary data
   - Prevents unnecessary thread divergence
   - Maintains memory coalescing for main data load

3. **Kernel Loading**:
   ```mojo
   if local_i < b_size:
       shared_b[local_i] = b[local_i]
   ```
   - Single load per thread
   - Bounded by kernel size

4. **Convolution Computation**:
   ```mojo
   if global_i < a_size:
       var local_sum: out.element_type = 0
       @parameter
       for j in range(CONV_2):
           if local_i + j < TPB + CONV_2 - 1:
               local_sum += shared_a[local_i + j] * shared_b[j]
   ```
   - Uses `@parameter` for compile-time loop unrolling
   - Proper type inference with `out.element_type`
   - Extended bounds check for overlap region

### Memory Access Pattern Analysis

1. **Block 0 Access Pattern**:
   ```txt
   Thread 0: [0 1 2 3] × [0 1 2 3]
   Thread 1: [1 2 3 4] × [0 1 2 3]
   Thread 2: [2 3 4 5] × [0 1 2 3]
   ...
   Thread 7: [7 8 9 10] × [0 1 2 3]  // Uses overlap data
   ```

2. **Block 1 Access Pattern**:
   ```txt
   Thread 0: [8 9 10 11] × [0 1 2 3]
   Thread 1: [9 10 11 12] × [0 1 2 3]
   ...
   Thread 7: [14 0 0 0] × [0 1 2 3]  // Zero padding at end
   ```

### Performance Optimizations

1. **Memory Coalescing**:
   - Main data load: Consecutive threads access consecutive memory
   - Boundary data: Only necessary threads participate
   - Single barrier synchronization point

2. **Thread Divergence Minimization**:
   - Clean separation of main and boundary loading
   - Uniform computation pattern within warps
   - Efficient bounds checking

3. **Shared Memory Usage**:
   - Optimal sizing to handle block boundaries
   - No bank conflicts in access pattern
   - Efficient reuse of loaded data

4. **Boundary Handling**:
   - Implicit zero padding at array end
   - Seamless block transition
   - Proper handling of edge cases

This implementation achieves efficient cross-block convolution while maintaining:
- Memory safety through proper bounds checking
- High performance through optimized memory access
- Clean code structure using LayoutTensor abstractions
- Minimal synchronization overhead
</div>
</details>
