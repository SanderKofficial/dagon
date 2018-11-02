/*
Copyright (c) 2017-2018 Timur Gafarov

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

module dagon.graphics.texture;

import std.stdio;
import std.math;

import dlib.core.memory;
import dlib.image.color;
import dlib.image.image;
import dlib.math.vector;

import dagon.core.libs;
import dagon.core.ownership;

class Texture: Owner
{
    SuperImage image;
    
    GLuint tex;
    GLenum format;
    GLint intFormat;
    GLenum type;
    
    int width;
    int height;
    int numMipmapLevels;
    
    Vector2f translation;
    Vector2f scale;
    float rotation;
    
    bool useMipmapFiltering = true;
    bool useLinearFiltering = true;

    this(Owner o)
    {
        super(o);
        translation = Vector2f(0.0f, 0.0f);
        scale = Vector2f(1.0f, 1.0f);
        rotation = 0.0f;
    }

    this(SuperImage img, Owner o, bool genMipmaps = false)
    {
        super(o);
        translation = Vector2f(0.0f, 0.0f);
        scale = Vector2f(1.0f, 1.0f);
        rotation = 0.0f;
        createFromImage(img, genMipmaps);
    }

    void createFromImage(SuperImage img, bool genMipmaps = true)
    {
        image = img;
        width = img.width;
        height = img.height;

        switch (img.pixelFormat)
        {
            case PixelFormat.L8:         intFormat = GL_R8;      format = GL_RED;  type = GL_UNSIGNED_BYTE; break;
            case PixelFormat.LA8:        intFormat = GL_RG8;     format = GL_RG;   type = GL_UNSIGNED_BYTE; break;
            case PixelFormat.RGB8:       intFormat = GL_RGB8;    format = GL_RGB;  type = GL_UNSIGNED_BYTE; break;
            case PixelFormat.RGBA8:      intFormat = GL_RGBA8;   format = GL_RGBA; type = GL_UNSIGNED_BYTE; break;
            case PixelFormat.RGBA_FLOAT: intFormat = GL_RGBA32F; format = GL_RGBA; type = GL_FLOAT; break;
            default:
                writefln("Unsupported pixel format %s", img.pixelFormat);
                return;
        }

        glGenTextures(1, &tex);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, tex);

        glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        
        //if (DerelictGL.isExtSupported("GL_EXT_texture_filter_anisotropic"))
        //    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAX_ANISOTROPY_EXT, 16.0f);
       
        glTexImage2D(GL_TEXTURE_2D, 0, intFormat, width, height, 0, format, type, cast(void*)img.data.ptr);

        //if (genMipmaps)
        glGenerateMipmap(GL_TEXTURE_2D);

        glBindTexture(GL_TEXTURE_2D, 0);
    }

    void bind()
    {
        if (glIsTexture(tex))
            glBindTexture(GL_TEXTURE_2D, tex);
            
        if (useMipmapFiltering)
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        else if (useLinearFiltering)
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        else
        {
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        }
    }

    void unbind()
    {
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        glBindTexture(GL_TEXTURE_2D, 0);
    }
    
    bool valid()
    {
        return cast(bool)glIsTexture(tex);
    }
    
    Color4f sample(float u, float v)
    {
        int x = cast(int)floor(u * width);
        int y = cast(int)floor(v * height);
        return image[x, y];
    }

    void release()
    {
        if (glIsTexture(tex))
            glDeleteTextures(1, &tex);
        if (image)
        {
            Delete(image);
            image = null;
        }
    }

    ~this()
    {
        release();
    }
}

