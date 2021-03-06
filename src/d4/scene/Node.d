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

module d4.scene.Node;

import d4.math.Matrix4;
import d4.renderer.Renderer;
import d4.scene.ISceneElement;
import d4.scene.ISceneVisitor;
import d4.scene.Mesh;

/**
 * A node in the tree-like scenegraph.
 *
 * It can contain any number of child nodes and meshes and stores a local
 * transformation matrix.
 */
class Node : ISceneElement {
public:
   /**
    * Constructs an empty node with no children and no local transformations.
    */
   this() {
      m_localMatrix = Matrix4.identity;
      m_worldMatrix = Matrix4.identity;
      m_worldMatrixValid = false;
   }

   /**
    * Adds a child node to the tree. If the node already has another parent
    * node, it is removed from the tree first.
    *
    * Params:
    *     childNode = The child node to add.
    */
   void addChild( Node childNode ) {
      if ( childNode.parent !is null ) {
         childNode.parent.removeChild( childNode );
      }

      m_children ~= childNode;
      childNode.parent = this;
   }

   /**
    * Removes a child node from the tree. This works only with direct children,
    * not with child nodes which are attached somewhere deep down the hierachy.
    *
    * Params:
    *     childNode = The child node to remove from the tree.
    */
   void removeChild( Node childNode ) {
      foreach ( i, currentNode; m_children ) {
         if ( currentNode == childNode ) {
            // Since the order is not important, simply replace the node at the
            // current index with the last one and truncate the last element.
            m_children[ i ] = m_children[ $-1 ];
            m_children = m_children[ 0 .. ( $ - 1 ) ];
            childNode.parent = null;
            return;
         }
      }
      throw new Exception( "Could not remove child: Node not found in child list." );
   }

   /**
    * Adds a child mesh to the node.
    *
    * Params:
    *     mesh = The mesh to add.
    */
   void addMesh( Mesh mesh ) {
      m_meshes ~= mesh;
   }

   /**
    * Accepts an ISceneVisitor, invoking its handling methods on the node and
    * all of its child meshes and nodes.
    *
    * Params:
    *     visitor = The ISceneVisitor to accept.
    */
   void accept( ISceneVisitor visitor ) {
      visitor.visitNode( this );

      foreach ( mesh; m_meshes ) {
         mesh.accept( visitor );
      }

      foreach ( node; m_children ) {
         node.accept( visitor );
      }
   }

   /**
    * The local transformation matrix.
    */
   Matrix4 transformation() {
      return m_localMatrix;
   }

   /// ditto
   void transformation( Matrix4 localMatrix ) {
      m_localMatrix = localMatrix;
      invalidateWorldMatrix();
   }

   /**
    * The world matrix of the node, i.e. the local transformation matrix
    * concatenated with the transformation matrices of all the parent nodes.
    *
    * This approach origined from before a »proper« scene graph was implemented,
    * it should be rethought if the half-baken scene graph is ever replaced with
    * a proper design.
    */
   Matrix4 worldMatrix() {
      // If our cached world matrix is invalid, we have to update it.
      if ( !m_worldMatrixValid ) {
         if ( m_parent !is null ) {
            // Apply the local matrix first, then the parent's matrix.
            m_worldMatrix = m_parent.worldMatrix * m_localMatrix;
         } else {
            m_worldMatrix = m_localMatrix;
         }
         m_worldMatrixValid = true;
      }

      return m_worldMatrix;
   }

protected:
   Node parent() {
      return m_parent;
   }

   void parent( Node parentNode ) {
      m_parent = parentNode;
      invalidateWorldMatrix();
   }

   void invalidateWorldMatrix() {
      m_worldMatrixValid = false;
      foreach ( node; m_children ) {
         node.invalidateWorldMatrix();
      }
   }

private:
   Node m_parent;
   Node[] m_children;

   Mesh[] m_meshes;
   Matrix4 m_localMatrix;
   Matrix4 m_worldMatrix;
   bool m_worldMatrixValid;
}
