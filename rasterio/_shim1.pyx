include "gdal.pxi"

from rasterio import dtypes
from rasterio.enums import Resampling

cimport numpy as np


cdef int delete_nodata_value(GDALRasterBandH hBand) except 3:
    raise NotImplementedError(
        "GDAL versions < 2.1 do not support nodata deletion")


cdef int io_band(GDALRasterBandH band, int mode, float x0, float y0,
                 float width, float height, object data, int resampling=0):
    """Read or write a region of data for the band.

    Implicit are

    1) data type conversion if the dtype of `data` and `band` differ.
    2) decimation if `data` and `band` shapes differ.

    The striding of `data` is passed to GDAL so that it can navigate
    the layout of ndarray views.
    """
    # GDAL handles all the buffering indexing, so a typed memoryview,
    # as in previous versions, isn't needed.
    cdef void *buf = <void *>np.PyArray_DATA(data)
    cdef int bufxsize = data.shape[1]
    cdef int bufysize = data.shape[0]
    cdef int buftype = dtypes.dtype_rev[data.dtype.name]
    cdef int bufpixelspace = data.strides[1]
    cdef int buflinespace = data.strides[0]

    cdef int xoff = <int>x0
    cdef int yoff = <int>y0
    cdef int xsize = <int>width
    cdef int ysize = <int>height
    cdef int retval = 3

    cdef char *stored_val = CPLGetConfigOption("GDAL_RASTERIO_RESAMPLING", NULL)

    val_b = Resampling(resampling).name.upper().encode('utf-8')
    cdef const char *val = val_b
    CPLSetConfigOption("GDAL_RASTERIO_RESAMPLING", val)

    with nogil:
        retval = GDALRasterIO(
            band, mode, xoff, yoff, xsize, ysize, buf, bufxsize, bufysize,
            buftype, bufpixelspace, buflinespace)

    CPLSetConfigOption("GDAL_RASTERIO_RESAMPLING", stored_val)
    CPLFree(stored_val)

    return retval


cdef int io_multi_band(GDALDatasetH hds, int mode, float x0, float y0,
                       float width, float height, object data,
                       long[:] indexes, int resampling=0):
    """Read or write a region of data for multiple bands.

    Implicit are

    1) data type conversion if the dtype of `data` and bands differ.
    2) decimation if `data` and band shapes differ.

    The striding of `data` is passed to GDAL so that it can navigate
    the layout of ndarray views.
    """
    cdef int i = 0
    cdef int retval = 3
    cdef int *bandmap = NULL
    cdef void *buf = <void *>np.PyArray_DATA(data)
    cdef int bufxsize = data.shape[2]
    cdef int bufysize = data.shape[1]
    cdef int buftype = dtypes.dtype_rev[data.dtype.name]
    cdef int bufpixelspace = data.strides[2]
    cdef int buflinespace = data.strides[1]
    cdef int bufbandspace = data.strides[0]
    cdef int count = len(indexes)

    cdef int xoff = <int>x0
    cdef int yoff = <int>y0
    cdef int xsize = <int>width
    cdef int ysize = <int>height

    cdef char *stored_val = CPLGetConfigOption("GDAL_RASTERIO_RESAMPLING", NULL)

    val_b = Resampling(resampling).name.upper().encode('utf-8')
    cdef const char *val = val_b
    CPLSetConfigOption("GDAL_RASTERIO_RESAMPLING", val)

    with nogil:
        bandmap = <int *>CPLMalloc(count*sizeof(int))
        for i in range(count):
            bandmap[i] = indexes[i]
        retval = GDALDatasetRasterIO(
            hds, mode, xoff, yoff, xsize, ysize, buf,
            bufxsize, bufysize, buftype, count, bandmap,
            bufpixelspace, buflinespace, bufbandspace)
        CPLFree(bandmap)

    CPLSetConfigOption("GDAL_RASTERIO_RESAMPLING", stored_val)
    CPLFree(stored_val)

    return retval


cdef int io_multi_mask(GDALDatasetH hds, int mode, float x0, float y0,
                       float width, float height, object data,
                       long[:] indexes, int resampling=0):
    """Read or write a region of data for multiple band masks.

    Implicit are

    1) data type conversion if the dtype of `data` and bands differ.
    2) decimation if `data` and band shapes differ.

    The striding of `data` is passed to GDAL so that it can navigate
    the layout of ndarray views.
    """
    cdef int i = 0
    cdef int j = 0
    cdef int retval = 3
    cdef GDALRasterBandH band = NULL
    cdef GDALRasterBandH hmask = NULL
    cdef void *buf = NULL
    cdef int bufxsize = data.shape[2]
    cdef int bufysize = data.shape[1]
    cdef int buftype = dtypes.dtype_rev[data.dtype.name]
    cdef int bufpixelspace = data.strides[2]
    cdef int buflinespace = data.strides[1]
    cdef int count = len(indexes)

    cdef int xoff = <int>x0
    cdef int yoff = <int>y0
    cdef int xsize = <int>width
    cdef int ysize = <int>height

    cdef char *stored_val = CPLGetConfigOption("GDAL_RASTERIO_RESAMPLING", NULL)

    val_b = Resampling(resampling).name.upper().encode('utf-8')
    cdef const char *val = val_b
    CPLSetConfigOption("GDAL_RASTERIO_RESAMPLING", val)

    for i in range(count):
        j = indexes[i]
        band = GDALGetRasterBand(hds, j)
        if band == NULL:
            raise ValueError("Null band")
        hmask = GDALGetMaskBand(band)
        if hmask == NULL:
            raise ValueError("Null mask band")
        buf = <void *>np.PyArray_DATA(data[i])
        if buf == NULL:
            raise ValueError("NULL data")
        with nogil:
            retval = GDALRasterIO(
                hmask, mode, xoff, yoff, xsize, ysize, buf, bufxsize,
                bufysize, 1, bufpixelspace, buflinespace)
            if retval:
                break
    CPLSetConfigOption("GDAL_RASTERIO_RESAMPLING", stored_val)
    CPLFree(stored_val)

    return retval
