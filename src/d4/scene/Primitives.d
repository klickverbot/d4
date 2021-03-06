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

/**
 * Helper functions for creating mesh representations of primitive objects.
 */
module d4.scene.Primitives;

import d4.math.AABB;
import d4.math.Vector3;
import d4.scene.Mesh;
import d4.scene.NormalVertex;
import d4.util.ArrayUtils;

/**
 * Creates a cuboid between the two specified points.
 *
 * Params:
 *    min = The corner with the smallest values in each component.
 *    max = The corner with the largest values in each component.
 *    inwards = Whether the faces point inwards or outwards.
 * Returns:
 *    A mesh containing the triangulated cuboid and no (null) material.
 */
Mesh makeCube( Vector3 min, Vector3 max, bool inwards = false ) {
   Mesh mesh = new Mesh();

   size_t[] faceIndices;
   if ( inwards ) {
      faceIndices = [ 0, 1, 2, 2, 1, 3 ];
   } else {
      faceIndices = [ 0, 2, 1, 1, 2, 3 ];
   }

   Vector3 normal;

   // Top.
   normal = Vector3( 0, 1, 0 );
   if ( inwards ) normal.invert();
   mesh.indices ~= faceIndices.add( mesh.vertices.length );
   mesh.vertices ~= [
      new NormalVertex( Vector3( min.x, max.y, max.z ), normal ),
      new NormalVertex( Vector3( min.x, max.y, min.z ), normal ),
      new NormalVertex( Vector3( max.x, max.y, max.z ), normal ),
      new NormalVertex( Vector3( max.x, max.y, min.z ), normal )
   ];

   // Bottom.
   normal = Vector3( 0, -1, 0 );
   if ( inwards ) normal.invert();
   mesh.indices ~= faceIndices.add( mesh.vertices.length );
   mesh.vertices ~= [
      new NormalVertex( Vector3( min.x, min.y, min.z ), normal ),
      new NormalVertex( Vector3( min.x, min.y, max.z ), normal ),
      new NormalVertex( Vector3( max.x, min.y, min.z ), normal ),
      new NormalVertex( Vector3( max.x, min.y, max.z ), normal )
   ];

   // Left wall.
   normal = Vector3( -1, 0, 0 );
   if ( inwards ) normal.invert();
   mesh.indices ~= faceIndices.add( mesh.vertices.length );
   mesh.vertices ~= [
      new NormalVertex( Vector3( min.x, max.y, max.z ), normal ),
      new NormalVertex( Vector3( min.x, min.y, max.z ), normal ),
      new NormalVertex( Vector3( min.x, max.y, min.z ), normal ),
      new NormalVertex( Vector3( min.x, min.y, min.z ), normal )
   ];

   // Right wall.
   normal = Vector3( 1, 0, 0 );
   if ( inwards ) normal.invert();
   mesh.indices ~= faceIndices.add( mesh.vertices.length );
   mesh.vertices ~= [
      new NormalVertex( Vector3( max.x, min.y, max.z ), normal ),
      new NormalVertex( Vector3( max.x, max.y, max.z ), normal ),
      new NormalVertex( Vector3( max.x, min.y, min.z ), normal ),
      new NormalVertex( Vector3( max.x, max.y, min.z ), normal )
   ];

   // Front wall.
   normal = Vector3( 0, 0, 1 );
   if ( inwards ) normal.invert();
   mesh.indices ~= faceIndices.add( mesh.vertices.length );
   mesh.vertices ~= [
      new NormalVertex( Vector3( min.x, min.y, max.z ), normal ),
      new NormalVertex( Vector3( min.x, max.y, max.z ), normal ),
      new NormalVertex( Vector3( max.x, min.y, max.z ), normal ),
      new NormalVertex( Vector3( max.x, max.y, max.z ), normal )
   ];

   // Back wall.
   normal = Vector3( 0, 0, -1 );
   if ( inwards ) normal.invert();
   mesh.indices ~= faceIndices.add( mesh.vertices.length );
   mesh.vertices ~= [
      new NormalVertex( Vector3( min.x, max.y, min.z ), normal ),
      new NormalVertex( Vector3( min.x, min.y, min.z ), normal ),
      new NormalVertex( Vector3( max.x, max.y, min.z ), normal ),
      new NormalVertex( Vector3( max.x, min.y, min.z ), normal )
   ];

   return mesh;
}

/**
 * Creates a cuboid from the given axis-aligned bounding box.
 *
 * Params:
 *    aabb = The bounding box.
 *    inwards = Whether the faces point inwards or outwards.
 * Returns:
 *    A mesh containing the triangulated cuboid and no (null) material.
 */
Mesh makeCube( AABB aabb, bool inwards = false ) {
   return makeCube( aabb.min, aabb.max, inwards );
}
