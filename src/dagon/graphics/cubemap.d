/*
Copyright (c) 2019-2020 Timur Gafarov

Boost Software License - Version 1.0 - August 17th, 2003
Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

module dagon.graphics.cubemap;

import std.stdio;
import std.math;
import std.traits;

import dlib.core.ownership;
import dlib.image.color;
import dlib.image.image;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.transformation;
import dlib.math.utils;

import dagon.core.bindings;
import dagon.graphics.texture;
import dagon.graphics.compressedimage;

enum CubeFace
{
    PositiveX = GL_TEXTURE_CUBE_MAP_POSITIVE_X,
    NegativeX = GL_TEXTURE_CUBE_MAP_NEGATIVE_X,
    PositiveY = GL_TEXTURE_CUBE_MAP_POSITIVE_Y,
    NegativeY = GL_TEXTURE_CUBE_MAP_NEGATIVE_Y,
    PositiveZ = GL_TEXTURE_CUBE_MAP_POSITIVE_Z,
    NegativeZ = GL_TEXTURE_CUBE_MAP_NEGATIVE_Z
}

class Cubemap: Texture
{
    this(Owner o)
    {
        super(o);
    }

    this(uint resolution, Owner o)
    {
        super(o);
        initialize(resolution);
    }

    ~this()
    {
        release();
    }

    void initialize()
    {
        releaseGLTexture();

        glActiveTexture(GL_TEXTURE0);

        glGenTextures(1, &tex);
        glBindTexture(GL_TEXTURE_CUBE_MAP, tex);

        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);

        glBindTexture(GL_TEXTURE_CUBE_MAP, 0);
    }

    void initialize(uint resolution)
    {
        releaseGLTexture();

        width = resolution;
        height = resolution;

        glActiveTexture(GL_TEXTURE0);

        glGenTextures(1, &tex);
        glBindTexture(GL_TEXTURE_CUBE_MAP, tex);

        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);

        glTexImage2D(GL_TEXTURE_CUBE_MAP_NEGATIVE_X, 0, GL_RGBA16F, resolution, resolution, 0, GL_RGBA, GL_FLOAT, null);
        glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X, 0, GL_RGBA16F, resolution, resolution, 0, GL_RGBA, GL_FLOAT, null);
        glTexImage2D(GL_TEXTURE_CUBE_MAP_NEGATIVE_Y, 0, GL_RGBA16F, resolution, resolution, 0, GL_RGBA, GL_FLOAT, null);
        glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_Y, 0, GL_RGBA16F, resolution, resolution, 0, GL_RGBA, GL_FLOAT, null);
        glTexImage2D(GL_TEXTURE_CUBE_MAP_NEGATIVE_Z, 0, GL_RGBA16F, resolution, resolution, 0, GL_RGBA, GL_FLOAT, null);
        glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_Z, 0, GL_RGBA16F, resolution, resolution, 0, GL_RGBA, GL_FLOAT, null);

        glBindTexture(GL_TEXTURE_CUBE_MAP, 0);
    }

    void setFaceImage(CubeFace face, SuperImage img)
    {
        if (img.width != img.height)
        {
            writefln("Cubemap face image must be square");
            return;
        }

        width = img.width;
        height = img.height;

        GLenum format;
        GLint intFormat;
        GLenum type;

        if (!pixelFormatToTextureFormat(cast(IntegerPixelFormat)img.pixelFormat, format, intFormat, type))
            writefln("Unsupported pixel format %s", img.pixelFormat);

        glBindTexture(GL_TEXTURE_CUBE_MAP, tex);
        glTexImage2D(face, 0, intFormat, width, height, 0, format, type, cast(void*)img.data.ptr);
        glBindTexture(GL_TEXTURE_CUBE_MAP, 0);
    }
    
    void fromEquirectangularMap(Texture tex)
    {
        fromEquirectangularMap(tex.image);
    }

    void fromEquirectangularMap(SuperImage envmap)
    {
        SuperImage faceImage = envmap.createSameFormat(width, width);

        foreach(i, face; EnumMembers!CubeFace)
        {
            Matrix4x4f dirTransform = cubeFaceMatrix(face);

            foreach(x; 0..width)
            foreach(y; 0..width)
            {
                float cubex = (cast(float)x / cast(float)width) * 2.0f - 1.0f;
                float cubey = (1.0f - cast(float)y / cast(float)width) * 2.0f - 1.0f;
                Vector3f dir = Vector3f(cubex, cubey, 1.0f).normalized * dirTransform;
                Vector2f uv = equirectProj(dir);
                Color4f c = bilinearPixel(envmap, uv.x * envmap.width, uv.y * envmap.height);
                faceImage[x, y] = c;
            }

            setFaceImage(face, faceImage);
        }

        faceImage.free();
    }
    
    void fromCompressedImage(CompressedImage img)
    {
        initialize();
        
        if (img.compressedFormat != CompressedImageFormat.RGBAF32 &&
            img.compressedFormat != CompressedImageFormat.RGBAF16)
        {
            writefln("Unsupported compressed format %s", img.compressedFormat);
            return;
        }
        
        uint width = img.width;
        uint height = img.height;
        uint numMipMaps = img.mipMapLevels;
        
        glBindTexture(GL_TEXTURE_CUBE_MAP, tex);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_BASE_LEVEL, 0);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAX_LEVEL, numMipMaps - 1);
        
        GLint intFormat = GL_RGBA32F;
        GLenum type = GL_FLOAT;
        uint pixelSize = 16;
        if (img.compressedFormat == CompressedImageFormat.RGBAF16)
        {
            intFormat = GL_RGBA16F;
            pixelSize = 8;
            type = GL_HALF_FLOAT;
        }
        
        ubyte* data = img.data.ptr;
        uint offset = 0;
        
        foreach(face; EnumMembers!CubeFace)
        {
            uint w = width;
            uint h = height;
            for (uint i = 0; i < numMipMaps; i++)
            {
                uint size = w * h * pixelSize;
                glTexImage2D(face, i, intFormat, w, h, 0, GL_RGBA, type, cast(void*)(data + offset));
                offset += size;
                w /= 2;
                h /= 2;
                if (offset >= img.data.length)
                {
                    writeln("Incomplete data");
                    break;
                }
            }
        }
        
        glBindTexture(GL_TEXTURE_CUBE_MAP, 0);
    }
    
    void fromImage(SuperImage img, uint resolution = 512)
    {
        CompressedImage compImage = cast(CompressedImage)img;
        if (compImage)
        {
            fromCompressedImage(compImage);
        }
        else
        {
            initialize(resolution);
            fromEquirectangularMap(img);
        }
    }

    override void bind()
    {
        if (glIsTexture(tex))
        {
            glBindTexture(GL_TEXTURE_CUBE_MAP, tex);

            if (!mipmapGenerated && useMipmapFiltering)
            {
                glGenerateMipmap(GL_TEXTURE_CUBE_MAP);
                mipmapGenerated = true;
            }
        }
    }

    override void unbind()
    {
        glBindTexture(GL_TEXTURE_CUBE_MAP, 0);
    }

    void invalidateMipmap()
    {
        mipmapGenerated = false;
    }
}

Matrix4x4f cubeFaceMatrix(CubeFace cf)
{
    switch(cf)
    {
        case CubeFace.PositiveX:
            return rotationMatrix(1, degtorad(-90.0f));
        case CubeFace.NegativeX:
            return rotationMatrix(1, degtorad(90.0f));
        case CubeFace.PositiveY:
            return rotationMatrix(0, degtorad(90.0f));
        case CubeFace.NegativeY:
            return rotationMatrix(0, degtorad(-90.0f));
        case CubeFace.PositiveZ:
            return rotationMatrix(1, degtorad(0.0f));
        case CubeFace.NegativeZ:
            return rotationMatrix(1, degtorad(180.0f));
        default:
            return Matrix4x4f.identity;
    }
}

Matrix4x4f cubeFaceCameraMatrix(CubeFace cf, Vector3f pos)
{
    Matrix4x4f m;
    switch(cf)
    {
        case CubeFace.PositiveX:
            m = translationMatrix(pos) * rotationMatrix(1, degtorad(90.0f)) * rotationMatrix(2, degtorad(180.0f));
            break;
        case CubeFace.NegativeX:
            m = translationMatrix(pos) * rotationMatrix(1, degtorad(-90.0f)) * rotationMatrix(2, degtorad(180.0f));
            break;
        case CubeFace.PositiveY:
            m = translationMatrix(pos) * rotationMatrix(1, degtorad(0.0f)) * rotationMatrix(0, degtorad(-90.0f));
            break;
        case CubeFace.NegativeY:
            m = translationMatrix(pos) * rotationMatrix(1, degtorad(0.0f)) * rotationMatrix(0, degtorad(90.0f));
            break;
        case CubeFace.PositiveZ:
            m = translationMatrix(pos) * rotationMatrix(1, degtorad(180.0f)) * rotationMatrix(2, degtorad(180.0f));
            break;
        case CubeFace.NegativeZ:
            m = translationMatrix(pos) * rotationMatrix(1, degtorad(0.0f)) * rotationMatrix(2, degtorad(180.0f));
            break;
        default:
            m = Matrix4x4f.identity; break;
    }
    return m;
}

Vector2f equirectProj(Vector3f dir)
{
    float phi = acos(dir.y);
    float theta = atan2(dir.x, dir.z) + PI;
    return Vector2f(theta / (PI * 2.0f), phi / PI);
}