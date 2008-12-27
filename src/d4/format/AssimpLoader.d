module d4.format.AssimpLoader;

import tango.stdc.stringz : fromStringz, toStringz;
import tango.io.Stdout;
import assimp.all;
import d4.math.Color;
import d4.math.Matrix4;
import d4.math.Vector3;
import d4.scene.Material;
import d4.scene.Mesh;
import d4.scene.Node;
import d4.scene.Vertex;

class AssimpLoader {
   this( char[] fileName ) {
      aiScene* scene = aiImportFile( toStringz( fileName ),
         aiProcess.JoinIdenticalVertices |
         aiProcess.ConvertToLeftHanded |
         aiProcess.Triangulate |
         aiProcess.FixInfacingNormals |
         /* aiProcess.GenSmoothNormals | */
         /* aiProcess.ValidateDataStructure | */
         aiProcess.ImproveCacheLocality |
         aiProcess.RemoveRedundantMaterials /*|
         aiProcess.OptimizeGraph |
         aiProcess.GenUVCoords */
      );

      if ( scene == null ) {
         throw new Exception( "Failed to load scene from file (" ~ fileName ~ "): " ~ fromStringz( aiGetErrorString() ) );
      }

      if ( scene.mRootNode == null ) {
         throw new Exception( "Model file contains no root node (" ~ fileName ~ ")." );
      }

      for ( uint i = 0; i < scene.mNumMaterials; ++i ) {
         m_materials ~= importMaterial( *( scene.mMaterials[ i ] ) );
      }

      for ( uint i = 0; i < scene.mNumMeshes; ++i ) {
         m_meshes ~= importMesh( *( scene.mMeshes[ i ] ) );
      }

      m_rootNode = importNode( *( scene.mRootNode ) );

      // Everything is parsed into our internal structures, we don't need the
      // assimp scene object anymore.
      aiReleaseImport( scene );
   }

   Node rootNode() {
      return m_rootNode;
   }

private:
   Material importMaterial( aiMaterial material ) {
      Material result = new Material();

      return result;
   }

   Mesh importMesh( aiMesh mesh ) {
      Mesh result = new Mesh();

      // If assimp's preprocessing worked correctly, the mesh should not be
      // empty and it should only contain triangles by now.
      assert( mesh.mNumFaces > 0 );
      assert( mesh.mPrimitiveTypes == aiPrimitiveType.TRIANGLE );

      for ( uint i = 0; i < mesh.mNumVertices; ++i ) {
         Vertex vertex = new Vertex();

         aiVector3D pos = mesh.mVertices[ i ];
         vertex.position = Vector3( pos.x, pos.y, pos.z );

         // TODO: Import other data.

         result.vertices ~= vertex;
      }

      for ( uint i = 0; i < mesh.mNumFaces; ++i ) {
         aiFace face = mesh.mFaces[ i ];

         // Since we are dealing with triangles, every face must have three vertices.
         assert( face.mNumIndices == 3 );

         result.indices ~= face.mIndices[ 0 ];
         result.indices ~= face.mIndices[ 1 ];
         result.indices ~= face.mIndices[ 2 ];
      }

      // The meshes store only incides for the global material buffer.
      assert( m_materials[ mesh.mMaterialIndex ] !is null );
      result.material = m_materials[ mesh.mMaterialIndex ];

      return result;
   }

   Node importNode( aiNode node ) {
      // TODO: Omit empty nodes as described in the assimp docs?
      Node result = new Node();

      result.transformation = importMatrix( node.mTransformation );

      for ( uint i = 0; i < node.mNumMeshes; ++i ) {
         // The nodes store only indices for the global mesh buffer.
         assert( m_meshes[ node.mMeshes[ i ] ] !is null );
         result.addMesh( m_meshes[ node.mMeshes[ i ] ] );
      }

      for ( uint i = 0; i < node.mNumChildren; ++i ) {
         result.addChild( importNode( *( node.mChildren[ i ] ) ) );
      }

      return result;
   }

   Matrix4 importMatrix( aiMatrix4x4 m ) {
      Matrix4 r;

      r.m11 = m.a1;
      r.m12 = m.a2;
      r.m13 = m.a3;
      r.m14 = m.a4;

      r.m21 = m.b1;
      r.m22 = m.b2;
      r.m23 = m.b3;
      r.m24 = m.b4;

      r.m31 = m.c1;
      r.m32 = m.c2;
      r.m33 = m.c3;
      r.m34 = m.c4;

      r.m41 = m.d1;
      r.m42 = m.d2;
      r.m43 = m.d3;
      r.m44 = m.d4;

      return r;
   }

   Mesh[] m_meshes;
   Material[] m_materials;
   Node m_rootNode;
}