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

module d4.app.Option;

/**
 * Convenience class for the command line support functionality.
 *
 * We currently cannot nest this into Application due to a compiler bug.
 * TODO: File LDC/DMD bug about this.
 */
class Option {
   this ( char[] newName, char[] newDescription ) {
      name = newName;
      description = newDescription;
   }
   char[] name;
   char[] description;

   int opCmp( Option rhs ) {
      return name < rhs.name ? -1 : name > rhs.name ? 1 : 0;
   }
}
