#ifndef _nImage__bmp_h_
#define _nImage__bmp_h_

#if defined(COMPILER_MSC) || defined(COMPILER_GCC)
#pragma pack(push, 1)
#endif

struct BMP_FILEHEADER {
	word    bfType;
	dword   bfSize;
	word    bfReserved1;
	word    bfReserved2;
	dword   bfOffBits;

	void    SwapEndian()
	{
#ifdef CPU_BIG_ENDIAN
		word tmp_bfType = bfType;
		dword tmp_bfSize = bfSize;
		dword tmp_bfOffBits = bfOffBits;
		Upp::EndianSwap(tmp_bfType);
		Upp::EndianSwap(tmp_bfSize);
		Upp::EndianSwap(tmp_bfOffBits);
		bfType = tmp_bfType;
		bfSize = tmp_bfSize;
		bfOffBits = tmp_bfOffBits;
#endif
	}
}
#ifdef COMPILER_GCC
__attribute__((packed))
#endif
;

struct BMP_INFOHEADER
{
	dword      biSize;
	int32      biWidth;
	int32      biHeight;
	word       biPlanes;
	word       biBitCount;
	dword      biCompression;
	dword      biSizeImage;
	int32      biXPelsPerMeter;
	int32      biYPelsPerMeter;
	dword      biClrUsed;
	dword      biClrImportant;

	void    SwapEndian()
	{
#ifdef CPU_BIG_ENDIAN
		dword tmp_biSize = biSize;
		int32 tmp_biWidth = biWidth;
		int32 tmp_biHeight = biHeight;
		word tmp_biPlanes = biPlanes;
		word tmp_biBitCount = biBitCount;
		dword tmp_biCompression = biCompression;
		dword tmp_biSizeImage = biSizeImage;
		int32 tmp_biXPelsPerMeter = biXPelsPerMeter;
		int32 tmp_biYPelsPerMeter = biYPelsPerMeter;
		dword tmp_biClrUsed = biClrUsed;
		dword tmp_biClrImportant = biClrImportant;
		Upp::EndianSwap(tmp_biSize);
		Upp::EndianSwap(tmp_biWidth);
		Upp::EndianSwap(tmp_biHeight);
		Upp::EndianSwap(tmp_biPlanes);
		Upp::EndianSwap(tmp_biBitCount);
		Upp::EndianSwap(tmp_biCompression);
		Upp::EndianSwap(tmp_biSizeImage);
		Upp::EndianSwap(tmp_biXPelsPerMeter);
		Upp::EndianSwap(tmp_biYPelsPerMeter);
		Upp::EndianSwap(tmp_biClrUsed);
		Upp::EndianSwap(tmp_biClrImportant);
		biSize = tmp_biSize;
		biWidth = tmp_biWidth;
		biHeight = tmp_biHeight;
		biPlanes = tmp_biPlanes;
		biBitCount = tmp_biBitCount;
		biCompression = tmp_biCompression;
		biSizeImage = tmp_biSizeImage;
		biXPelsPerMeter = tmp_biXPelsPerMeter;
		biYPelsPerMeter = tmp_biYPelsPerMeter;
		biClrUsed = tmp_biClrUsed;
		biClrImportant = tmp_biClrImportant;
#endif
	}
}
#ifdef COMPILER_GCC
__attribute__((packed))
#endif
;

struct BMP_RGB
{
    byte    rgbBlue;
    byte    rgbGreen;
    byte    rgbRed;
    byte    rgbReserved;
};

struct BMP_ICONDIR {
	word           idReserved;   // Reserved (must be 0)
	word           idType;       // Resource Type (1 for icons)
	word           idCount;      // How many images?
}
#ifdef COMPILER_GCC
__attribute__((packed))
#endif
;

struct BMP_ICONDIRENTRY {
	byte        bWidth;          // Width, in pixels, of the image
	byte        bHeight;         // Height, in pixels, of the image
	byte        bColorCount;
	byte        bReserved;
	short       wHotSpotX;
	short       wHotSpotY;
	dword       dwBytesInRes;    // How many bytes in this resource?
	dword       dwImageOffset;   // Where in the file is this image?
}
#ifdef COMPILER_GCC
__attribute__((packed))
#endif
;

#if defined(COMPILER_MSC) || defined(COMPILER_GCC)
#pragma pack(pop)
#endif

struct BMPHeader : public BMP_INFOHEADER
{
	BMP_RGB palette[256];
};

#endif
