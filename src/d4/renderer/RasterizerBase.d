/*
 * Copyright © 2010, klickverbot <klickverbot@gmail.com>.
 *
 * This file is part of d4, which is free software: you can redistribute it
 * and/or modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, either version 3 of the License,
 * or (at your option) any later version.
 *
 * d4 is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * d4. If not, see <http://www.gnu.org/licenses/>.
 */

module d4.renderer.RasterizerBase;

import tango.math.Math : rndint;
import d4.math.Color;
import d4.math.Matrix4;
import d4.math.Plane;
import d4.math.Texture;
import d4.math.Vector2;
import d4.math.Vector3;
import d4.math.Vector4;
import d4.output.Surface;
import d4.renderer.IRasterizer;
import d4.renderer.ZBuffer;
import d4.scene.Vertex;
import d4.util.ArrayAllocation;

/**
 * Provides common basic functionality for most kinds of rasterizers.
 * This includes: shader support, matrix caching, clipping, backface culling, …
 *
 * The concrete subclasses only need to implement <code>drawTriangle</code>,
 * everything else is handled by this class.
 */
abstract class RasterizerBase( bool PrepareForPerspectiveCorrection,
   alias Shader, ShaderParams... ) : IRasterizer {
protected:
   /**
    * Imports the shader template passed to the class template into the class
    * scope.
    *
    * The shader has to provide:
    *  - void vertexShader( in Vertex vertex, out Vector4 position,
    *    out VertexVariables variables );
    *
    *  - Color pixelShader( VertexVariables variables );
    *
    *  - struct VertexVariables{}: This set of vertex shader outputs, which
    *    has to consist entirely of floats and floats nested in structs
    *    (e.g. Vector3), is linearly interpolated for each pixel and passed to
    *    the pixel shader.
    *
    * It may provide:
    *  - struct ShaderConstants{}: The instance accesible via shaderConstants()
    *    can be used to pass values to the shader which need to be modified at
    *    runtime.
    */
   mixin Shader!( ShaderParams );
   static if ( !is ( ShaderConstants ) ) { struct ShaderConstants{} }

public:
   /**
    * Initializes the render states and transformation matrices
    * with sane default values.
    */
   this() {
      m_worldMatrix = Matrix4.identity;
      m_worldNormalMatrix = Matrix4.identity;
      m_viewMatrix = Matrix4.identity;
      m_projMatrix = Matrix4.identity;
      updateWorldViewMatrix();
      updateWorldViewProjMatrix();

      m_backfaceCulling = BackfaceCulling.CULL_CW;
   }

   /**
    * Renders a set of indexed triangles using the stored transformations.
    *
    * The results are written to the Frame-/Z-Buffer specified by
    * <code>setRenderTarget</code>.
    *
    * Params:
    *     vertices = The vertices to render.
    *     indices = The indices referring to the passed vertex array.
    */
   final void renderTriangleList( Vertex[] vertices, size_t[] indices ) {
      assert( ( indices.length % 3 == 0 ),
         "There must be no incomplete triangles." );

      // Invoke vertex shader to get the positions in clipping coordinates
      // and to compute any additional per-vertex data.
      TransformedVertex[] transformed;
      allocate( transformed, vertices.length );

      foreach ( i, vertex; vertices ) {
         TransformedVertex current;

         vertexShader( vertex, current.pos, current.vars );
         // Note: The positions are still not divided by w (»homogenzied«).

         transformed[ i ] = current;
      }

      for ( size_t i = 0; i < indices.length; i += 3 ) {
         renderTriangle( transformed[ indices[ i ] ],
            transformed[ indices[ i + 1 ] ], transformed[ indices[ i + 2 ] ] );
      }

      free( transformed );
   }

   /**
    * Sets the render target to use, which is a framebuffer and its z buffer
    * companion.
    *
    * Params:
    *     colorBuffer = The framebuffer to use.
    *     zBuffer = The z buffer to use.
    */
   final void setRenderTarget( Surface colorBuffer, ZBuffer zBuffer ) {
      assert( colorBuffer.width == zBuffer.width,
         "Z buffer width must match framebuffer width." );
      assert( colorBuffer.height == zBuffer.height,
         "Z buffer height must match framebuffer height." );

      m_colorBuffer = colorBuffer;
      m_zBuffer = zBuffer;
   }


   /**
    * The world matrix to use.
    */
   final Matrix4 worldMatrix() {
      return m_worldMatrix;
   }

   /// ditto
   final void worldMatrix( Matrix4 worldMatrix ) {
      m_worldMatrix = worldMatrix;
      m_worldNormalMatrix = worldMatrix.inversed().transposed();
      updateWorldViewMatrix();
      updateWorldViewProjMatrix();
   }

   /**
    * The view matrix to use.
    */
   final Matrix4 viewMatrix() {
      return m_viewMatrix;
   }

   /// ditto
   final void viewMatrix( Matrix4 viewMatrix ) {
      m_viewMatrix = viewMatrix;
      updateWorldViewMatrix();
      updateWorldViewProjMatrix();
   }

   /**
    * The projection matrix to use.
    */
   final Matrix4 projectionMatrix() {
      return m_projMatrix;
   }

   /// ditto
   final void projectionMatrix( Matrix4 projectionMatrix ) {
      m_projMatrix = projectionMatrix;
      updateWorldViewProjMatrix();
   }

   /**
    * The backface culling mode to use.
    */
   final BackfaceCulling backfaceCulling() {
      return m_backfaceCulling;
   }

   /// ditto
   final void backfaceCulling( BackfaceCulling cullingMode ) {
      m_backfaceCulling = cullingMode;
   }

   /**
    * The textures to use.
    */
   final Texture[] textures() {
      return m_textures;
   }

   /// ditto
   final void textures( Texture[] textures ) {
      m_textures = textures;
      m_textureData = [];
      m_shiftedWidths = [];
      m_shiftedHeights = [];
      m_shiftedXLimits = [];
      m_shiftedYLimits = [];

      foreach ( i, texture; textures ) {
         m_textureData ~= texture.colorData;
         m_texWidths ~= texture.width;
         m_texHeights ~= texture.height;
         m_shiftedWidths ~= texture.width << TEX_COORD_SHIFT;
         m_shiftedHeights ~= texture.height << TEX_COORD_SHIFT;
         m_shiftedXLimits ~= ( texture.width - 1 ) << TEX_COORD_SHIFT;
         m_shiftedYLimits ~= ( texture.height - 1 ) << TEX_COORD_SHIFT;
      }
   }

   final ShaderConstants* shaderConstants() {
      return &m_shaderConstants;
   }

protected:
   /*
    * Shader interface.
    */

   /**
    * Returns: A matrix which transforms model normals into world space.
    */
   final Matrix4 worldNormalMatrix() {
      return m_worldNormalMatrix;
   }

   /**
    * Returns: A matrix which transforms a vector from model space to clipping
    *    space.
    */
   final Matrix4 worldViewProjMatrix() {
      return m_worldViewProjMatrix;
   }

   /**
    * Reads color information from the specified texture.
    *
    * If the first template parameter, <code>bilinearInterpolation</code> is
    * set to true, bilinear interpolation is used to compute the color value.
    * Otherwise, the color of the nearest pixel is returned.
    *
    * If the second template parameter, <code>tile</code> is set to true, the
    * texture is tiled if the coordinates exceed the (0,0)–(1,1) range. If not,
    * the color values of the edge pixels are repeated (known as »clamping«).
    *
    * Params:
    *    texIndex = The index of the texture to read from.
    *    texCoords = The coordinates of the point to read the color information
    *       from the texture. Note that the OpenGL convention is
    * Returns:
    *    The color read from the texture.
    */
   final Color readTexture( bool bilinearInterpolation = false, bool tile = true )
      ( uint texIndex, Vector2 texCoords ) {

      // Some fixed-point math is used to here to speed up the very time-critical
      // filtering code. For an example of more elaborate optimizations, see:
      // http://www.flipcode.com/archives/Bilinear_Filtering_Interpolation.shtml.
      int u;
      int v;

      static if ( tile ) {
         // Tile.
         u = rndint( texCoords.x * m_shiftedXLimits[ texIndex ] ) %
            m_shiftedWidths[ texIndex ];
         v = rndint( texCoords.y * m_shiftedYLimits[ texIndex ] ) %
            m_shiftedHeights[ texIndex ];
      } else {
         // Clamp.
         u = rndint( texCoords.x * m_shiftedXLimits[ texIndex ] );
         v = rndint( texCoords.y * m_shiftedYLimits[ texIndex ] );
         if ( u < 0 ) {
            u = 0;
         } else if ( u > m_shiftedXLimits[ texIndex ] ) {
            u = m_shiftedXLimits[ texIndex ];
         }
         if ( v < 0 ) {
            v = 0;
         } else if ( v > m_shiftedYLimits[ texIndex ] ) {
            v = m_shiftedYLimits[ texIndex ];
         }
      }

      // Remove the low extra bits.
      int u0 = u >> TEX_COORD_SHIFT;
      int v0 = v >> TEX_COORD_SHIFT;

      static if ( !bilinearInterpolation ) {
         // We probably should round correctly for the uninterpolated mode
         // instead of just truncating the lower bits, but nobody will see
         // that anyway...
         return m_textureData[ texIndex ][ v0 * m_texWidths[ texIndex ] + u0 ];
      } else {
         // Read the four surrounding pixels.
         //
         // v
         // ^
         // | .  .  .  .
         // | . 01 11  .
         // | . 00 10  .
         // | .  .  .  .
         // X———————————> u
         //
         // u0 and v0 were rounded down by truncating the low bits above, so by
         // adding 1 to them, we get the indices of the four pixels surrounding
         // the precise position.
         int u1 = ( u0 + 1 ) % m_texWidths[ texIndex ];
         int v1 = ( v0 + 1 ) % m_texHeights[ texIndex ];
         Color c00 = m_textureData[ texIndex ][ u0 + m_texWidths[ texIndex ] * v0 ];
         Color c10 = m_textureData[ texIndex ][ u1 + m_texWidths[ texIndex ] * v0 ];
         Color c01 = m_textureData[ texIndex ][ u0 + m_texWidths[ texIndex ] * v1 ];
         Color c11 = m_textureData[ texIndex ][ u1 + m_texWidths[ texIndex ] * v1 ];

         // The value of the lower, added bits is effectively the distance of
         // the precise sampling position to 00, its inverse the distance to 11.
         const LOWER_BITS_MASK = ( 1 << TEX_COORD_SHIFT ) - 1;
         int lu = u & LOWER_BITS_MASK;
         int ilu = LOWER_BITS_MASK + 1 - lu;
         int lv = v & LOWER_BITS_MASK;
         int ilv = LOWER_BITS_MASK + 1 - lv;

         // Interpolation code template for a single channel.
         char[] c( char[] n ) {
            return
               "( ( " ~
                  "( cast(uint) c00."~n~" * ilu + lu * c10."~n~" ) * ilv +" ~
                  "( cast(uint) c01."~n~" * ilu + lu * c11."~n~" ) * lv" ~
               ") >> ( TEX_COORD_SHIFT * 2 ) )";
         }

         return Color( mixin( c( "r" ) ), mixin( c( "g" ) ), mixin( c( "b" ) ) );
      }
   }


   /*
    * Helper functions for handling VertexVariables.
    *
    * The code below uses template magic to auto-generate the code for applying
    * mathematical operations to VertexVariables only consisting of floats
    * and structs with floats or other structs in them.
    */

   final T scale( T )( T vector, float factor ) {
      T result;
      foreach ( i, value; vector.tupleof ) {
         alias typeof( value ) ElementType;
         static if ( is( ElementType == float ) ) {
            result.tupleof[ i ] = value * factor;
         } else static if ( is ( ElementType == struct )  ) {
            result.tupleof[ i ] = scale( value, factor );
         } else {
            static assert( false,
               "Invalid type used in VertexVariables: " ~ ElementType.stringof );
         }
      }
      return result;
   }

   final T add( T )( T first, T second ) {
      T result;
      foreach ( i, _; result.tupleof ) {
         alias typeof( result.tupleof[ i ] ) ElementType;
         static if ( is( ElementType == float ) ) {
            result.tupleof[ i ] = first.tupleof[ i ] + second.tupleof[ i ];
         } else static if ( is ( ElementType == struct ) ) {
            result.tupleof[ i ] = add( first.tupleof[ i ], second.tupleof[ i ] );
         } else {
            static assert( false,
               "Invalid type used in VertexVariables: " ~ ElementType.stringof );
         }
      }
      return result;
   }

   final T substract( T )( T first, T second ) {
      T result;
      foreach ( i, _; result.tupleof ) {
         alias typeof( result.tupleof[ i ] ) ElementType;
         static if ( is( ElementType == float ) ) {
            result.tupleof[ i ] = first.tupleof[ i ] - second.tupleof[ i ];
         } else static if ( is ( ElementType == struct ) ) {
            result.tupleof[ i ] = substract( first.tupleof[ i ], second.tupleof[ i ] );
         } else {
            static assert( false,
               "Invalid type used in VertexVariables: " ~ ElementType.stringof );
         }
      }
      return result;
   }

   /**
    * Linearly interpolates between the values[] of two instances of
    * <code>VertexVariables</code>.
    *
    * Params:
    *    first = The first set of values.
    *    second = The second set of values.
    *    position = The position between the variables. 0 for this parameter
    *       yields first, 1 yields second.
    * Returns:
    *    first * position + second * (1-position)
    */
   final VertexVariables lerp( VertexVariables first, VertexVariables second,
      float position ) {
      return add( first, scale( substract( second, first ), position ) );
   }


   /*
    * Interface for Rasterizer implementations.
    */

   /**
    * Rasterizes the specified triangle to the screen.
    *
    * The values of the per-vertex data at the pixel position are interpolated
    * and fed into the pixel shader to compute the color value.
    *
    * Params:
    *   positions = The vertex positions in screen coordinates.
    *   variables = The per-vertex variables.
    */
   abstract void drawTriangle( Vector4 pos0, VertexVariables vars0, Vector4 pos1,
      VertexVariables vars1, Vector4 pos2, VertexVariables vars2 );

   /**
    * The color buffer to write the output to.
    * It is set by setRenderTarget.
    */
   Surface m_colorBuffer;

   /**
    * The Z buffer to use for the visibility calculations.
    * It is set by <code>setRenderTarget</code>.
    */
   ZBuffer m_zBuffer;

private:
   /**
    * Recalculates the cached world-view combo matrix.
    */
   void updateWorldViewMatrix() {
      m_worldViewMatrix = m_viewMatrix * m_worldMatrix;
   }

   /**
    * Recalculates the cached world-view-projection combo matrix.
    */
   void updateWorldViewProjMatrix() {
      m_worldViewProjMatrix = m_projMatrix * m_worldViewMatrix;
   }

   /**
    * Convinience struct for storing the transformed vertices.
    */
   struct TransformedVertex {
      Vector4 pos;
      VertexVariables vars;
   }

   /**
    * View frustrum (clipping) planes for homogeneous clipping.
    *
    * HACK: They are nudged slightly so that floating point inaccuracies do not
    *    lead to artifacts with the top-left filling convention.
    */
   const float VIEWPORT_NUDGE = 0.00001f;
   const CLIPPING_PLANES = [
      Plane( 1, 0, 0, 1 + VIEWPORT_NUDGE ),   // Left
      Plane( -1, 0, 0, 1 - VIEWPORT_NUDGE ),  // Right
      Plane( 0, -1, 0, 1 + VIEWPORT_NUDGE ),  // Top
      Plane( 0, 1, 0, 1 - VIEWPORT_NUDGE ),   // Bottom
      Plane( 0, 0, 1, 0 ),   // Near
      Plane( 0, 0, 1, 1 )    // Far
   ];

   /**
    * The maximum number of vertices a clipped triangle can have. 8 because
    * the triangle can be clipped by up to 4 sides of the viewing volume.
    */
   const CLIPPING_BUFFER_SIZE = 8;

   /**
    * Buffers used to sotre the vertices during and after clipping.
    */
   TransformedVertex[ CLIPPING_BUFFER_SIZE ] m_clippingBuffer0;
   TransformedVertex[ CLIPPING_BUFFER_SIZE ] m_clippingBuffer1; /// ditto

   /**
    * Renders a transformed triangle to the screen.
    */
   void renderTriangle( TransformedVertex vertex0, TransformedVertex vertex1,
      TransformedVertex vertex2 ) {
      // Clip all vertices against the view frustrum, which is now a cuboid from
      // [ -1; -1; 0 ] to [ 1, 1, 1 ]. To do this, we us homogeneous clipping,
      // which is fast and happens before the coordinates are divided by w.
      // We assume that there are never more than CLIPPING_BUFFER_SIZE vertices
      // created during clipping.
      // We can only work with an even number of clipping planes since we expect
      // the result to be in m_clippingBuffer0.
      static assert( CLIPPING_PLANES.length % 2 == 0 );

      m_clippingBuffer0[ 0 ] = vertex0;
      m_clippingBuffer0[ 1 ] = vertex1;
      m_clippingBuffer0[ 2 ] = vertex2;
      uint vertexCount = 3;

      foreach ( i, plane; CLIPPING_PLANES ) {
         if ( i & 1 ) {
            // Even (second, forth, ...) pass (i==0 on the first pass).
            vertexCount = clipToPlane( m_clippingBuffer1, m_clippingBuffer0,
               vertexCount, plane );
         } else {
            // Uneven (first, third, ...) pass.
            vertexCount = clipToPlane( m_clippingBuffer0, m_clippingBuffer1,
               vertexCount, plane );
         }
         if ( vertexCount < 3 ) {
            // There is nothing left to be drawn.
            return;
         }
      }

      // Transform the vertices to screen coordinates.
      float halfViewportWidth = 0.5f * m_colorBuffer.width;
      float halfViewportHeight = 0.5f * m_colorBuffer.height;

      for( uint i = 0; i < vertexCount; ++i ) {
         // TODO: How to use a ref instead of a pointer?
         TransformedVertex* vertex = &m_clippingBuffer0[ i ];

         // Divide the vertex coordinates by w to get the »normal« (projected)
         // positions.
         float invW = 1 / vertex.pos.w;
         vertex.pos.x *= invW;
         vertex.pos.y *= invW;
         vertex.pos.z *= invW;

         static if ( PrepareForPerspectiveCorrection ) {
            // Additionally, divide all vertex variables by w so that we can
            // linearly interpolate between them in screen space. Save invW to
            // the w-coordinate so that we can reconstruct the original values
            // later.
            vertex.vars = scale( vertex.vars, invW );
            vertex.pos.w = invW;
         }

         // Transform the position into viewport coordinates. We have to invert
         // the y-coordinate because the y-axis is pointing in the other
         // direction in the viewport coordinate system.
         vertex.pos.x = ( vertex.pos.x + 1f ) * halfViewportWidth;
         vertex.pos.y = ( 1f - vertex.pos.y ) * halfViewportHeight;
      }

      // As we already have screen coordinates, looking at the z-coordinate
      // of the cross product of two triangle sides is enough. If it is
      // positive, the vertices are oriented clockwise, if it is negative
      // the vertices are oriented counter-clockwise.
      // TODO: Find the optimal position in the pipeline for this.
      if ( m_backfaceCulling != BackfaceCulling.NONE ) {
         Vector4 p0 = m_clippingBuffer0[ 0 ].pos;
         Vector4 p1 = m_clippingBuffer0[ 1 ].pos;
         Vector4 p2 = m_clippingBuffer0[ 2 ].pos;

         float crossZ = ( p1.x - p0.x ) * ( p2.y - p0.y ) -
            ( p1.y - p0.y ) * ( p2.x - p0.x );
         if ( ( m_backfaceCulling == BackfaceCulling.CULL_CCW ) && ( crossZ < 0 ) ) {
            return;
         }

         if ( ( m_backfaceCulling == BackfaceCulling.CULL_CW ) && ( crossZ > 0 ) ) {
            return;
         }
      }

      // Triangulate the polygon produced by clipping and draw each triangle
      // to the screen.
      uint triangleCount = vertexCount - 2;
      for ( uint i = 0; i < triangleCount; ++i ) {
         drawTriangle(
            m_clippingBuffer0[ 0 ].pos,
            m_clippingBuffer0[ 0 ].vars,
            m_clippingBuffer0[ i + 1 ].pos,
            m_clippingBuffer0[ i + 1 ].vars,
            m_clippingBuffer0[ i + 2 ].pos,
            m_clippingBuffer0[ i + 2 ].vars
         );
      }
   }

   /**
    * Clips a polygon against a plane using homogeneous clipping.
    *
    * Params:
    *     sourceBuffer = The buffer to read the source vertices from.
    *     targetBuffer = The buffer to write the clipped vertices to.
    *     vertexCount = The number of vertices in the source buffer.
    *     plane = The plane to clip against.
    * Returns: The number of vertices in the target buffer.
    */
   uint clipToPlane( TransformedVertex[] sourceBuffer,
      TransformedVertex[] targetBuffer, uint vertexCount, Plane plane ) {
      // Due to some function overloading strangeness, we have to alias the other
      // interpolation functions.
      alias d4.math.Vector4.lerp lerpVector;
      alias lerp lerpVars;

      TransformedVertex lerpVertex( TransformedVertex first,
         TransformedVertex second, float position ) {
         TransformedVertex result = void;
         result.pos = lerpVector( first.pos, second.pos, position );
         result.vars = lerpVars( first.vars, second.vars, position );
         return result;
      }

      uint newCount = 0;

      for ( uint i = 0, j = 1; i < vertexCount; ++i, ++j ) {
         if ( j == vertexCount ) {
            // "Wrap" over the end to clip the last->first edge.
            j = 0;
         }

         // Distances of the current and the next vertex to the clipping plane.
         float currDist = plane.classifyHomogenous( sourceBuffer[ i ].pos );
         float nextDist = plane.classifyHomogenous( sourceBuffer[ j ].pos );

         if ( currDist >= 0.f ) {
            // The current vertex is »inside«, append it to the result.
            assert( newCount < CLIPPING_BUFFER_SIZE,
               "Created too many vertices during clipping!" );
            targetBuffer[ newCount++ ] = sourceBuffer[ i ];

            if ( nextDist < 0.f ) {
               // The edge to the next vertex is crossing the plane, interpolate
               // the vertex which is exactly on the plane and append it to the
               // result.
               assert( newCount < CLIPPING_BUFFER_SIZE,
                  "Created too many vertices during clipping!" );
               targetBuffer[ newCount++ ] = lerpVertex(
                  sourceBuffer[ i ],
                  sourceBuffer[ j ],
                  currDist / ( currDist - nextDist )
               );
            }
         } else if ( nextDist >= 0.f ) {
            // The next vertex is inside, also append the vertex on the plane.
            assert( newCount < CLIPPING_BUFFER_SIZE,
               "Created too many vertices during clipping!" );
            targetBuffer[ newCount++ ] = lerpVertex(
               sourceBuffer[ i ],
               sourceBuffer[ j ],
               currDist / ( currDist - nextDist )
            );
         }
      }

      return newCount;
   }

   ShaderConstants m_shaderConstants;

   Matrix4 m_worldMatrix;
   Matrix4 m_worldNormalMatrix;
   Matrix4 m_viewMatrix;
   Matrix4 m_projMatrix;
   Matrix4 m_worldViewMatrix;
   Matrix4 m_worldViewProjMatrix;

   BackfaceCulling m_backfaceCulling;

   Texture[] m_textures;
   Color[][] m_textureData;

   /*
    * The performance of the texture reading code typically has a large impact
    * on the overall speed of the application. Hence, the dimensions are
    * pre-processed for use with fixed-point math when a new set of textures is
    * activated and just read from the cache in readTexture().
    */
   uint[] m_shiftedWidths;
   uint[] m_shiftedHeights;
   uint[] m_shiftedXLimits;
   uint[] m_shiftedYLimits;
   uint[] m_texWidths;
   uint[] m_texHeights;

   /**
    * The number of bits in the subpixel part of the fixed-point texture
    * coordinates used for bilinear interpolation.
    *
    * For instance, if the value is 8, the integer coordinates are shifted
    * 8 bits to the left, so 24 bits are remaining for the integer part.
    */
   const TEX_COORD_SHIFT = 8;
}
