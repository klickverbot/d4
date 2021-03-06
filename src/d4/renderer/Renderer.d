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

module d4.renderer.Renderer;

import tango.math.Math : PI;
import tango.util.container.HashMap;
import d4.math.Color;
import d4.math.Matrix4;
import d4.math.Texture;
import d4.math.Transformations;
import d4.math.Vector3;
import d4.math.Vector4;
import d4.output.Surface;
import d4.renderer.IMaterial;
import d4.renderer.IRasterizer;
import d4.renderer.SolidRasterizer;
import d4.renderer.WireframeRasterizer;
import d4.renderer.ZBuffer;
import d4.scene.Vertex;
import d4.shader.SingleColorShader;

alias d4.renderer.IRasterizer.BackfaceCulling BackfaceCulling;

/**
 * The central interface to the rendering system.
 *
 * To render triangles, call <code>beginScene</code> first, then
 * <code>renderTriangleList</code> for any number of times and finally
 * <code>endScene</code> to finish the rendering process.
 */
class Renderer {
public:
   /**
    * Constructs a new renderer instance with the given render target.
    *
    * Params:
    *     renderTarget = The target to render to.
    */
   this( Surface renderTarget ) {
      m_renderTarget = renderTarget;
      m_zBuffer = new ZBuffer( renderTarget.width, renderTarget.height );
      m_clearColor = Color( 0, 0, 0 );

      m_activeRasterizer = new WireframeRasterizer!( SingleColorShader );
      m_activeRasterizer.setRenderTarget( m_renderTarget, m_zBuffer );
      setProjection( PI / 2, 0.1f, 100.f );

      m_materialRasterizers = new MaterialRasterizerMap();

      m_rendering = false;
   }

   /**
    * Begins the rendering process.
    *
    * Params:
    *     clearColor = Whether to clear the framebuffer.
    *     clearZ = Whether to clear the z buffer.
    */
   void beginScene( bool clearColor = true, bool clearZ = true ) {
      assert( !m_rendering );
      m_rendering = true;
      m_renderTarget.lock();

      if ( clearColor ) {
         m_renderTarget.clear( m_clearColor );
      }
      if ( clearZ ) {
         m_zBuffer.clear();
      }
   }

   /**
    * Renders a set of indexed triangles.
    *
    * Params:
    *     vertices = The vertices to render.
    *     indices = The indices referring to the passed vertex array.
    */
   void renderTriangleList( Vertex[] vertices, size_t[] indices ) {
      assert( m_rendering );

      m_activeRasterizer.renderTriangleList( vertices, indices );
   }

   /**
    * Ends the rendering process.
    *
    * You have to call this before calling <code>beginScene</code> again.
    */
   void endScene() {
      assert( m_rendering );
      m_renderTarget.unlock();
      m_rendering = false;
   }

   /**
    * Configures the renderer to use the specified material to render triangles.
    *
    * Params:
    *     material = The material to activate.
    */
   void activateMaterial( IMaterial material ) {
      if ( !m_materialRasterizers.containsKey( material ) ) {
         m_materialRasterizers.add( material, material.createRasterizer() );
      }

      activateRasterizer( m_materialRasterizers[ material ] );
      material.prepareForRendering( this );
   }


   /**
    * The world matrix to use.
    */
   Matrix4 worldMatrix() {
      return m_activeRasterizer.worldMatrix;
   }

   /// ditto
   void worldMatrix( Matrix4 worldMatrix ) {
      m_activeRasterizer.worldMatrix = worldMatrix;
   }

   /**
    * The view matrix to use.
    */
   Matrix4 viewMatrix() {
      return m_activeRasterizer.viewMatrix;
   }

   /// ditto
   void viewMatrix( Matrix4 viewMatrix ) {
      m_activeRasterizer.viewMatrix = viewMatrix;
   }

   /**
    * Sets the (perspective) projection to use for rendering.
    *
    * Params:
    *     fovRadians = The vertical viewing angle (in radians).
    *     nearDistance = The distance of the near clipping plane (>0).
    *     farDistance = The distance of the far clipping plane (>nearDistance).
    */
   void setProjection( float fovRadians, float nearDistance, float farDistance ) {
      m_activeRasterizer.projectionMatrix = perspectiveProjectionMatrix(
         fovRadians,
         cast( float ) m_renderTarget.width / m_renderTarget.height,
         nearDistance,
         farDistance
      );
   }

   /**
    * Which type of backface culling to use.
    */
   BackfaceCulling backfaceCulling() {
      return m_activeRasterizer.backfaceCulling;
   }

   /// ditto
   void backfaceCulling( BackfaceCulling cullingMode ) {
      m_activeRasterizer.backfaceCulling = cullingMode;
   }

   /**
    * The color to clear the framebuffer with when a new frame is started.
    */
   Color clearColor() {
      return m_clearColor;
   }

   /// ditto
   void clearColor( Color clearColor ) {
      m_clearColor = clearColor;
   }

private:
   void activateRasterizer( IRasterizer rasterizer ) {
      if ( rasterizer == m_activeRasterizer ) {
         return;
      }

      rasterizer.worldMatrix = m_activeRasterizer.worldMatrix;
      rasterizer.viewMatrix = m_activeRasterizer.viewMatrix;
      rasterizer.projectionMatrix = m_activeRasterizer.projectionMatrix;
      rasterizer.backfaceCulling = m_activeRasterizer.backfaceCulling;

      m_activeRasterizer = rasterizer;
      m_activeRasterizer.setRenderTarget( m_renderTarget, m_zBuffer );
   }

   Color m_clearColor;
   bool m_rendering;

   alias HashMap!( IMaterial, IRasterizer ) MaterialRasterizerMap;
   MaterialRasterizerMap m_materialRasterizers;
   IRasterizer m_activeRasterizer;

   Surface m_renderTarget;
   ZBuffer m_zBuffer;
}
