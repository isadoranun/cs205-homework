import numpy as np
cimport numpy as np
cimport cython
import numpy
cimport AVX
from cython.parallel import prange


cdef AVX.float8 magnitude_squared(AVX.float8 z_real, AVX.float8 z_imag) nogil:
    return AVX.fmadd(z_real, z_real, AVX.mul(z_imag, z_imag))


cdef void counts_to_output(AVX.float8 counts,
                      np.uint32_t [:, :] out_counts,
                      int i, int j) nogil:
    
    cdef:
        float tmp_counts[8]
        int jj
        
    AVX.to_mem(counts, &(tmp_counts[0])) 
    
    for jj in range(8):
        out_counts[i, 8*j+jj] =  <int>tmp_counts[jj]
         
                
@cython.boundscheck(False)
@cython.wraparound(False)
cpdef mandelbrot(np.complex64_t [:, :] in_coords,
                 np.uint32_t [:, :] out_counts,
                 int max_iterations=511):
    cdef:
       int i, j, iter
       AVX.float8 c_real, c_imag, z_real, z_imag, mask, accepted, iterations, ones, z_real_tmp

       # To declare AVX.float8 variables, use:
       # cdef:
       #     AVX.float8 v1, v2, v3
       #
       # And then, for example, to multiply them
       #     v3 = AVX.mul(v1, v2)
       #
       # You may find the numpy.real() and numpy.imag() fuctions helpful.

    assert in_coords.shape[1] % 8 == 0, "Input array must have 8N columns"
    assert in_coords.shape[0] == out_counts.shape[0], "Input and output arrays must be the same size"
    assert in_coords.shape[1] == out_counts.shape[1],  "Input and output arrays must be the same size"

    with nogil:
       
        for i in prange(in_coords.shape[0], schedule='static',chunksize=1,num_threads = 1):
            for j in range(in_coords.shape[1]/8):
                
                iterations = AVX.float_to_float8(0.0)
                ones = AVX.float_to_float8(1.0)
                
                    
                c_real = AVX.make_float8((in_coords[i,j*8+7]).real,
                             (in_coords[i,j*8+6]).real,
                             (in_coords[i,j*8+5]).real,
                             (in_coords[i,j*8+4]).real,
                             (in_coords[i,j*8+3]).real,
                             (in_coords[i,j*8+2]).real,
                             (in_coords[i,j*8+1]).real,
                             (in_coords[i,j*8]).real)
                
                c_imag = AVX.make_float8((in_coords[i,j*8+7]).imag,
                             (in_coords[i,j*8+6]).imag,
                             (in_coords[i,j*8+5]).imag,
                             (in_coords[i,j*8+4]).imag,
                             (in_coords[i,j*8+3]).imag,
                             (in_coords[i,j*8+2]).imag,
                             (in_coords[i,j*8+1]).imag,
                             (in_coords[i,j*8]).imag)
                
               
                z_real = AVX.float_to_float8(0.0)
                z_imag = AVX.float_to_float8(0.0)
                
                
                
                for iter in range(max_iterations):
                        
                    mask = AVX.greater_than(AVX.float_to_float8(4), magnitude_squared(z_real, z_imag))
                    accepted = AVX.bitwise_and(mask, ones)
                    
                    
                    iterations = AVX.add(accepted, iterations)
                        
                    if AVX.signs(mask) == 0:
                        break
                    
                    # (a+bj)(a+bj)
                    # a^2 + jab + jab + j^2b^2
                    #(a^2 - b^2) + j(2ab)
                    z_real_tmp = AVX.add(AVX.fmsub(z_real, z_real, AVX.mul(z_imag, z_imag)), c_real)
                    z_imag = AVX.fmadd(AVX.float_to_float8(2.0), AVX.mul(z_real, z_imag), c_imag)
                    
                    z_real = z_real_tmp
             
                        
                counts_to_output(iterations, out_counts, i, j) 
                


# An example using AVX instructions
cpdef example_sqrt_8(np.float32_t[:] values):
    cdef:
        AVX.float8 avxval, tmp, mask
        float out_vals[8], hola[8]
        float [:] out_view = out_vals

    assert values.shape[0] == 8

    # Note that the order of the arguments here is opposite the direction when
    # we retrieve them into memory.
    avxval = AVX.make_float8(values[7],
                             values[6],
                             values[5],
                             values[4],
                             values[3],
                             values[2],
                             values[1],
                             values[0])

    avxval = AVX.sqrt(avxval)

    # mask will be true where 2.0 < avxval
    mask = AVX.less_than(AVX.float_to_float8(2.0), avxval)
   
    #AVX.to_mem(mask, &(hola[0]))
    #print np.array(hola)                

    # invert mask and select off values, so should be 2.0 >= avxval
    avxval = AVX.bitwise_andnot(mask, avxval)
    
    #AVX.to_mem(avxval, &(hola[0]))
    #print np.array(hola)  
    
    AVX.to_mem(avxval, &(out_vals[0]))
    
    return np.array(out_view)
