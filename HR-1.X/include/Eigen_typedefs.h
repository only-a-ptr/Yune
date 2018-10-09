/******************************************************************************
 *  This file is part of "Helion-Render".
 *
 *  Copyright (C) 2018 by Umair Ahmed and Syed Moiz Hussain.
 *
 *  "Helion-Render" is a Physically based Renderer using Bi-Directional Path Tracing.
 *  Right now the renderer only  works for devices that support OpenCL and OpenGL.
 *
 *  "Helion-Render" is a free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  "Helion-Render" is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 ******************************************************************************/

#ifndef EIGEN_TYPEDEFS_H
#define EIGEN_TYPEDEFS_H

#include <Eigen/Core>

/** \file Eigen_typedefs.h
 * \brief This file defines Eigen typedefs for ease of use.
 *
 * Since we aren't doing any sort of processing here, we can disable alignment when we only want to use storage.
 * This is can be done by defining global macro in project options **EIGEN_DONT_ALIGN**. This class is used only
 * to shorten the type names as I'm more familiar with GLM. However since NanoGUI uses Eigen, better to stick to 1 math library.
 *
 * For users who wouldn't like to use the macro, they can use the un-aligned types instead, beware though,
 * Even when using these types you will run into alignment issues in operations which use aliasing such as
 * assigning the result of matrix multiplication involving Mat A to Mat A. This would require creating a temporary
 * and Eigen uses aligned matrices for this as far as I discerned.
 */


typedef Eigen::Vector3f Vec3f;
typedef Eigen::Vector4f Vec4f;
typedef Eigen::Matrix4f Mat3x3f;
typedef Eigen::Matrix4f Mat4x4f;



typedef Eigen::Matrix<float,3,1, Eigen::DontAlign> UVec3f;
typedef Eigen::Matrix<float,4,1, Eigen::DontAlign> UVec4f;
typedef Eigen::Matrix<float,3,3, Eigen::DontAlign> UMat3x3f;
typedef Eigen::Matrix<float,4,4, Eigen::DontAlign> UMat4x4f;


#endif // EIGEN_TYPEDEFS_H
