module d4.scene.TexturedNormalVertex;

import d4.math.Vector2;
import d4.math.Vector3;
import d4.scene.Vertex;

/**
 * A vertex consisting of a position vector, a normal vector, and a pair of
 * texture coordinates.
 *
 * This is the standard for lit, textured models.
 */
class TexturedNormalVertex : Vertex {
public:
   /**
    * The vertex normal vector.
    */
   Vector3 normal() {
      return m_normal;
   }

   /// ditto
   void normal( Vector3 normal ) {
      m_normal = normal;
   }

   /**
    * The vertex texture coordinates.
    */
   Vector2 texCoords() {
      return m_texCoords;
   }

   /// ditto
   void texCoords( Vector2 texCoords ) {
      m_texCoords = texCoords;
   }

private:
   Vector3 m_normal;
   Vector2 m_texCoords;
}
