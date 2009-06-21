/**
 * Simple model viewer.
 *
 * Expects at least one parameter, the model file to display.
 *
 * Additional parameters:
 *   - smoothNormals: If there are no normals present in the model file,
 *     smoothed ones are generated (hard faces otherwise).
 *   - fakeColors: Assings a random color to each vertex.
 */
module Viewer;

import tango.core.Array;
import tango.io.Stdout;
import tango.math.Math : sin, PI;
import d4.format.AssimpScene;
import d4.math.Color;
import d4.math.Matrix4;
import d4.math.Quaternion;
import d4.math.Transformations;
import d4.scene.Node;
import d4.scene.Scene;
import d4.scene.Vertex;
import d4.util.Key;
import FreeCameraApplication;

/**
 * The main application class.
 * Manages the scene, reacts to user input, etc.
 */
class Viewer : FreeCameraApplication {
public:
   this( char[][] args ) {
      // Parse command line options.
      if ( args.length < 2 ) {
         throw new Exception( "Please specify a model file at the command line." );
      }

      m_sceneFileName = args[ 1 ];

      if ( contains( args[ 2..$ ], "smoothNormals" ) ) {
         m_generateSmoothNormals = true;
      }

      if ( contains( args[ 2..$ ], "fakeColors" ) ) {
         m_fakeColors = true;
      }
   }
protected:
   override void init() {
      super.init();

      assert( m_sceneFileName.length > 0 );

      Stdout.newline;
      m_scene = new AssimpScene( m_sceneFileName, m_generateSmoothNormals, m_fakeColors );

      m_rotateWorld = false;
      m_animateBackground = false;
      m_backgroundTime = 0;
      renderer().clearColor = Color( 0, 0, 0 );
   }

   override void render( float deltaTime ) {
      super.render( deltaTime );

      if ( m_animateBackground ) {
         updateRainbowBackground( deltaTime );
      }
      if ( m_rotateWorld ) {
         updateRotatingWorld( deltaTime );
      }

      renderer().beginScene();
      m_scene.rootNode.render( renderer() );
      renderer().endScene();
   }

   override void shutdown() {
      super.shutdown();
   }

   override void handleKeyUp( Key key ) {
      super.handleKeyUp( key );

      switch ( key ) {
         case Key.v:
            m_rotateWorld = !m_rotateWorld;
            break;
         case Key.b:
            m_animateBackground = !m_animateBackground;
            break;
         default:
            // Do nothing.
            break;
      }
   }

private:
   void updateRainbowBackground( float deltaTime ) {
      m_backgroundTime += deltaTime;
      ubyte red = 128 + cast( ubyte )( 128 * sin( m_backgroundTime ) );
      ubyte green = 128 + cast( ubyte )( 128 * sin( m_backgroundTime - 1 ) );
      ubyte blue = 128 + cast( ubyte )( 128 * sin( m_backgroundTime + 1 ) );
      renderer().clearColor = Color( red, green, blue );
   }

   void updateRotatingWorld( float deltaTime ) {
      Matrix4 rotation = zRotationMatrix( deltaTime * 0.3 );
      rotation *= yRotationMatrix( deltaTime * 0.7 );
      rotation *= xRotationMatrix( deltaTime * 1.2 );

      m_scene.rootNode.transformation = rotation * m_scene.rootNode.transformation;
   }

   char[] m_sceneFileName;
   bool m_generateSmoothNormals;
   bool m_fakeColors;

   Scene m_scene;

   bool m_rotateWorld;
   bool m_animateBackground;
   float m_backgroundTime;
}

import util.EntryPoint;
debug {
   mixin EntryPoint!( Viewer, true );
} else {
   mixin EntryPoint!( Viewer );
}
