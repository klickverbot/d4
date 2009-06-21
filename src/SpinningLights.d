module SpinningLights;

import d4.format.AssimpScene;
import d4.math.Texture;
import d4.math.Transformations;
import d4.math.Vector3;
import d4.renderer.IMaterial;
import d4.renderer.IRasterizer;
import d4.renderer.Renderer;
import d4.renderer.SolidRasterizer;
import d4.scene.Scene;
import d4.scene.NormalVertex;
import d4.shader.VertexVariableUtils;
import util.EntryPoint;
import FreeCameraApplication;
import RoomScene;

template Shader() {
   import tango.math.Math : sqrt;
   import d4.scene.NormalVertex;

   const AMBIENT_INTENSITY = 0f;
//   const DIFFUSE_COLOR_0 = Color( 0, 127, 255 );
//   const DIFFUSE_COLOR_1 = Color( 255, 128, 0 );
   const DECAY_0 = 0.05f;
   const DECAY_1 = 0.1f;

   void vertexShader( in Vertex vertex, out Vector4 position, out VertexVariables variables ) {
      NormalVertex nv = cast( NormalVertex ) vertex;
      assert( nv !is null );

      position = worldViewProjMatrix * nv.position;
      variables.normal = worldNormalMatrix.rotateVector( nv.normal ).normalized();
      variables.localPosition = nv.position;
   }

   Color pixelShader( VertexVariables variables ) {
      Vector3 normal = variables.normal.normalized();
      
      Vector3 toLight0 = shaderConstants.light0LocalPosition - variables.localPosition;
      float decayFactor0 = 1f / ( 1 + toLight0.sqrLength() * DECAY_0 );
      toLight0.normalize();
      
      Vector3 toLight1 = shaderConstants.light1LocalPosition - variables.localPosition;
      float decayFactor1 = 1f / ( 1 + toLight1.sqrLength() * DECAY_1 );
      toLight1.normalize();

      Color result = Color( 255, 255, 255 ) * AMBIENT_INTENSITY;

      // TODO: Prevent »color overruns«.

      float diffuseFactor0 = toLight0.dot( normal );
      if ( diffuseFactor0 > 0 ) {
         result += Color( 0, 127, 255 ) * diffuseFactor0 * decayFactor0;
      }

      float diffuseFactor1 = toLight1.dot( normal );
      if ( diffuseFactor1 > 0 ) {
         result += Color( 255, 128, 0 ) * diffuseFactor1 * decayFactor1;
      }

      return result;
   }

   struct ShaderConstants {
      Vector3 light0LocalPosition;
      Vector3 light1LocalPosition;
   }

   struct VertexVariables {
      float[6] values;
      mixin( vector3Variable!( "normal", 0 ) );
      mixin( vector3Variable!( "localPosition", 3 ) );
   }
}

class Material : IMaterial {
   this() {
      m_light0Position = Vector3( -3f, 2.5f, 3f );
      m_light1Position = Vector3( 4f, 4f, 2f );
   }
   
   void updatePositions( float deltaTime ) {
      m_light0Position = rotationMatrix( rotationQuaternion(
         -deltaTime/2, Vector3( 0, 1, 0 ) ) ).transformLinear( m_light0Position );
      m_light1Position = rotationMatrix( rotationQuaternion(
         deltaTime, Vector3( 0, 1, 0 ) ) ).transformLinear( m_light1Position );
   }
   
   IRasterizer getRasterizer() {
      if ( m_rasterizer is null ) {
         m_rasterizer = new Rasterizer();
      }

      return m_rasterizer;
   }

   void prepareForRendering( Renderer renderer ) {
      m_rasterizer.shaderConstants.light0LocalPosition =
         renderer.worldMatrix.inversed().transformLinear( m_light0Position );
      m_rasterizer.shaderConstants.light1LocalPosition =
         renderer.worldMatrix.inversed().transformLinear( m_light1Position );
   }

   bool usesTextures() {
      return false;
   }

private:
   Vector3 m_light0Position;
   Vector3 m_light1Position;
   
   alias SolidRasterizer!( true, Shader ) Rasterizer;
   Rasterizer m_rasterizer;
}


class SpinningLights : FreeCameraApplication {
   this( char[][] args ) {
      // Parse command line options.
      if ( args.length < 2 ) {
         // Render a white »room« by default if no model file is given.
         m_scene = new RoomScene( 5 );
      } else {
         m_scene = new AssimpScene( args[ 1 ] );
      }
   }

protected:
   override void init() {
      super.init();

      // TODO: Add global material override function to material manager instead?
      m_material = new Material();
      auto allMeshes = m_scene.rootNode.flatten();
      foreach ( mesh; allMeshes ) {
         mesh.material = m_material;
      }

      cameraPosition = Vector3( 0, 3, 5 );
   }

   override void render( float deltaTime ) {
      super.render( deltaTime );
      
      m_material.updatePositions( deltaTime );

      renderer().beginScene();
      m_scene.rootNode.render( renderer() );
      renderer().endScene();
   }

   override void shutdown() {
      super.shutdown();
   }

private:
   char[] m_sceneFileName;
   Scene m_scene;
   Material m_material;
}

mixin EntryPoint!( SpinningLights );