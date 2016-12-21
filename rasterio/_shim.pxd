include "gdal.pxi"

cdef int delete_nodata_value(GDALRasterBandH hBand) except 3
cdef int io_band(GDALRasterBandH band, int mode, float xoff, float yoff,
                 float width, float height, object data, int resampling=*)
cdef int io_multi_band(GDALDatasetH hds, int mode, float xoff, float yoff,
                       float width, float height, object data, long[:] indexes,
                       int resampling=*)
cdef int io_multi_mask(GDALDatasetH hds, int mode, float xoff, float yoff,
                       float width, float height, object data, long[:] indexes,
                       int resampling=*)
