module d4.renderer.WireframeRasterizer;

import tango.io.Stdout;
import tango.math.Math : abs;
import d4.math.Color;
import d4.math.Vector4;
import d4.renderer.RasterizerBase;

final class WireframeRasterizer( alias Shader ) : RasterizerBase!( Shader ) {
protected:
   void drawTriangle( Vector4[ 3 ] positions, VertexVariables[ 3 ] variables ) {
      Color color = Color( 0, 0, 0 );
      drawLine( positions[ 0 ], positions[ 1 ], color );
      drawLine( positions[ 1 ], positions[ 2 ], color );
      drawLine( positions[ 2 ], positions[ 0 ], color );
   }
   
private:
   void drawLine( Vector4 startPos, Vector4 endPos, Color color ) {
      int startX = cast( int ) startPos.x;
      int startY = cast( int ) startPos.y;

      int endX = cast( int ) endPos.x;
      int endY = cast( int ) endPos.y;

      int x = startX;
      int y = startY;

      int error;
      int errorPerPixel;
      int errorResetStep;

      int deltaX = abs( endX - startX );
      int deltaY = abs( endY - startY );

      // Check if line is going from the left to the right or the other way round.
      int xStep = ( endX - startX ) > 0 ? 1 : -1;

      // Check if line is going down or up.
      int yStep = ( endY - startY ) > 0 ? 1 : -1;

      // Check if line is going flat (deltaY/deltaX < 1) or steep.
      if ( deltaY < deltaX ) {
         error = -deltaX;
         errorPerPixel = 2 * deltaY;
         errorResetStep = 2 * error;

         while ( x != endX ) {
            m_colorBuffer.setPixel( x, y, color );
            error += errorPerPixel;

            if ( error > 0 ) {
               y += yStep;
               error += errorResetStep;
            }

            x += xStep;
         }
      } else {
         error = -deltaY;
         errorPerPixel = 2 * deltaX;
         errorResetStep = 2 * error;

         while ( y != endY ) {
            m_colorBuffer.setPixel( x, y, color );
            error += errorPerPixel;

            if ( error > 0 ) {
               x += xStep;
               error += errorResetStep;
            }

            y += yStep;
         }
      }

      m_colorBuffer.setPixel( endX, endY, color );
   }
}