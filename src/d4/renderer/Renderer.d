module d4.renderer.Renderer;

import tango.io.Stdout;
import tango.math.Math : PI;
import d4.math.Color;
import d4.math.Matrix4;
import d4.math.Vector3;
import d4.math.Vector4;
import d4.output.Surface;
import d4.renderer.DefaultShader;
import d4.renderer.IRasterizer;
import d4.renderer.WireframeRasterizer;
import d4.renderer.ZBuffer;
import d4.scene.Vertex;

enum TriangleOrientation {
   CCW,
   CW
}

/**
 * The central interface to the rendering system.
 */
class Renderer {
public:
   this( Surface renderTarget ) {
      m_renderTarget = renderTarget;
      m_zBuffer = new ZBuffer( renderTarget.width, renderTarget.height );
      m_clearColor = Color( 0, 0, 0 );

      m_activeRasterizer = new WireframeRasterizer!( DefaultShader )();
      m_activeRasterizer.setRenderTarget( m_renderTarget, m_zBuffer );
      setProjection( PI / 2, 0.1f, 10.f );

      m_rendering = false;
   }

   void beginScene( bool clear = true ) {
      assert( !m_rendering );
      m_rendering = true;
      m_renderTarget.lock();

      if ( clear ) {
         m_renderTarget.clear( m_clearColor );
      }
   }

   /**
    * Renders a set of indexed triangles.
    * 
    * Params:
    *     vertices = The vertices to render.
    *     indices = The indices referring to the passed vertex array.
    */
   void renderTriangleList( Vertex[] vertices, uint[] indices ) {
      assert( m_rendering );

      m_activeRasterizer.renderTriangleList( vertices, indices );
   }

   void endScene() {
      assert( m_rendering );
      m_renderTarget.unlock();
      m_rendering = false;
   }


   Matrix4 worldMatrix() {
      return m_activeRasterizer.worldMatrix;
   }

   void worldMatrix( Matrix4 worldMatrix ) {
      m_activeRasterizer.worldMatrix = worldMatrix;
   }

   Matrix4 viewMatrix() {
      return m_activeRasterizer.viewMatrix;
   }

   void viewMatrix( Matrix4 viewMatrix ) {
      m_activeRasterizer.viewMatrix = viewMatrix;
   }

   void setProjection( float fovRadians, float nearDistance, float farDistance ) {
      m_activeRasterizer.projectionMatrix = Matrix4.perspectiveProjection(
         fovRadians,
         cast( float ) m_renderTarget.width / m_renderTarget.height,
         nearDistance,
         farDistance
      );
   }

   Color clearColor() {
      return m_clearColor;
   }

   void clearColor( Color clearColor ) {
      m_clearColor = clearColor;
   }

   bool cullBackfaces() {
      if ( m_triangleOrientation == TriangleOrientation.CCW ) {
         return m_activeRasterizer.backfaceCulling == BackfaceCulling.CW;
      } else if ( m_triangleOrientation == TriangleOrientation.CW ) {
         return m_activeRasterizer.backfaceCulling == BackfaceCulling.CCW;
      }
   }

   void cullBackfaces( bool performCulling ) {
      if( performCulling ) {
         if ( m_triangleOrientation == TriangleOrientation.CCW ) {
            m_activeRasterizer.backfaceCulling = BackfaceCulling.CW;
         } else if ( m_triangleOrientation == TriangleOrientation.CW ) {
            m_activeRasterizer.backfaceCulling = BackfaceCulling.CCW;
         }
      } else {
         m_activeRasterizer.backfaceCulling = BackfaceCulling.NONE;
      }
   }

   TriangleOrientation triangleOrientation() {
      return m_triangleOrientation;
   }

   void triangleOrientation( TriangleOrientation orientation ) {
      bool performCulling = cullBackfaces();
      m_triangleOrientation = orientation;
      cullBackfaces( performCulling );
   }
   
private:
   IRasterizer m_activeRasterizer;

   Surface m_renderTarget;
   ZBuffer m_zBuffer;

   Color m_clearColor;
   bool m_rendering;

   TriangleOrientation m_triangleOrientation;
}