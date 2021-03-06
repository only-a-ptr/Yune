#define PI              3.14159265359f
#define INV_PI          0.31830988618f
#define EPSILON         0.0001f
#define RR_THRESHOLD    4
#define LIGHT_SIZE      1
#define HEAP_SIZE       1500
#define BDPT_BOUNCES    20
//#define MIS

typedef struct Mat4x4{
    float4 r1;
    float4 r2;
    float4 r3;
    float4 r4;
} Mat4x4;

typedef struct Ray{

    float4 origin;
    float4 dir;
    float length;
    bool is_shadow_ray;
} Ray;

typedef struct HitInfo{

    int  triangle_ID, light_ID;
    float4 hit_point;  // point of intersection.
    float4 normal;

} HitInfo;

typedef struct PathInfo {
	
	HitInfo hit_info;
	float4 dir;
    float4 contrib;
    float fwd_pdf;
    float rev_pdf;    
	
} PathInfo;

typedef struct Quad{

    float4 pos;
    float4 norm;
    float4 ke;
    float4 kd;
    float4 ks;
    float4 edge_l;
    float4 edge_w;
    float phong_exponent;

} Quad;

typedef struct Triangle{

    float4 v1;
    float4 v2;
    float4 v3;
    float4 vn1;
    float4 vn2;
    float4 vn3;
    int matID;       // total size till here = 100 bytes
    float pad[3];    // padding 12 bytes - to make it 112 bytes (next multiple of 16
} Triangle;

//For use with Triangle geometry.
typedef struct Material{

    float4 ke;
    float4 kd;
    float4 ks;
    float n;
    float k;
    float px;
    float py;
    float alpha_x;
    float alpha_y;
    int is_specular;
    int is_transmissive;    // total 80 bytes.
} Material;

typedef struct AABB{    
    float4 p_min;
    float4 p_max;
}AABB;

typedef struct BVHNodeGPU{
    AABB aabb;          //32 
    int vert_list[10]; //40
    int child_idx;      //4
    int vert_len;       //4 - total 80
} BVHNodeGPU;

typedef struct Camera{
    Mat4x4 view_mat;
    float view_plane_dist;  // total 68 bytes
    float pad[3];           // 12 bytes padding to reach 80 (next multiple of 16)
} Camera;

__constant sampler_t sampler = CLK_NORMALIZED_COORDS_FALSE |
                           CLK_ADDRESS_CLAMP_TO_EDGE   |
                           CLK_FILTER_NEAREST;

__constant Quad light_sources[LIGHT_SIZE] = { {     (float4)(-0.1979f, 0.703f, -3.1972f, 1.f),
                                                    (float4)(0.f, 1.f, 0.f, 0.f),      //norm
                                                    (float4)(18.3f, 16.2f, 14.5f, 0.f),    //ke col
                                                    (float4)(0.f, 0.f, 0.f, 0.f),       //diffuse col
                                                    (float4)(0.f, 0.f, 0.f, 0.f),       //specular col
                                                    (float4)(0.4f, 0.f, 0.f, 0.f),       //edge_l
                                                    (float4)(0.f, 0.f, 0.4f, 0.f),       //edge_w
                                                    0.f                                  //phong exponent
                                               }
                                            };

__constant float4 SKY_COLOR =(float4) (0.588f, 0.88f, 1.0f, 1.0f);
__constant float4 BACKGROUND_COLOR =(float4) (0.4f, 0.4f, 0.4f, 1.0f);
__constant float4 PINK = (float4) (0.988f, 0.0588f, 0.7529f, 1.0f);

//Core Functions
void createRay(float pixel_x, float pixel_y, int img_width, int img_height, Ray* eye_ray, constant Camera* main_cam);
bool traceRay(Ray* ray, HitInfo* hit, int bvh_size, __global BVHNodeGPU* bvh, int scene_size, __global Triangle* scene_data);
void createLightPath(PathInfo* light_path, int* path_length, uint* seed, int bvh_size, __global BVHNodeGPU* bvh, int scene_size, __global Triangle* scene_data, __global Material* mat_data);
void createEyePath(PathInfo* eye_path, int* path_length, Ray eye_ray, uint* seed, int bvh_size, __global BVHNodeGPU* bvh, int scene_size, __global Triangle* scene_data, __global Material* mat_data);
float4 shading(int2 pixel, Ray ray, Ray light_ray, int GI_CHECK, uint* seed, int bvh_size, __global BVHNodeGPU* bvh, int scene_size, __global Triangle* scene_data,  __global Material* mat_data);
float4 evaluateDirectLighting(int2 pixel, float4 w_o, HitInfo hit, uint* seed, int bvh_size, __global BVHNodeGPU* bvh, int scene_size, __global Triangle* scene_data,  __global Material* mat_data);
float4 evaluateBRDF(float4 w_i, float4 w_o, HitInfo hit_info, bool sample_glossy, float rr_prob, __global Triangle* scene_data, __global Material* mat_data );
int sampleLights(HitInfo hit_info, float* light_pdf, float4* w_i, uint* seed);

//Intersection Routiens
bool rayAabbIntersection(Ray* ray, AABB bb);
bool traverseBVH(Ray* ray, HitInfo* hit_info, int bvh_size, __global BVHNodeGPU* bvh, __global Triangle* scene_data);
bool rayTriangleIntersection(Ray* ray, HitInfo* hit, __global Triangle* scene_data, int idx);

//Sampling Hemisphere Functions
void phongSampleHemisphere (Ray* ray, float* pdf, float4 w_o, HitInfo hit_info, uint* seed,  __global Triangle* scene_data, __global Material* mat_data);
void uniformSampleHemisphere(Ray* ray, float* pdf, HitInfo hit_info, uint* seed);
void cosineWeightedHemisphere(Ray* ray, float* pdf, HitInfo hit_info, uint* seed);

//PDF functions to return PDF values provided a ray direction and for converting PDFs between solid angle/area
float calcPhongPDF(float4 w_i, float4 w_o, HitInfo hit_info, __global Triangle* scene_data, __global Material* mat_data);
float calcCosPDF(float4 w_i, float4 normal);
float convertPdfAngleToPdfArea(float pdf_angle, HitInfo curr, HitInfo next);

// Helper Functions
float4 inverseGammaCorrect(float4 color);
float getYluminance(float4 color);
uint wang_hash(uint seed);
uint xor_shift(uint seed);
void powerHeuristic(float* weight, float light_pdf, float brdf_pdf, int beta);
bool sampleGlossyPdf(HitInfo hit, __global Triangle* scene_data, __global Material* mat_data, uint* seed, float* prob);


/***********************  KERNEL START  ************************/


__kernel void pathtracer(__write_only image2d_t outputImage, __read_only image2d_t inputImage, __constant Camera* main_cam, 
                         int scene_size, __global Triangle* scene_data, __global Material* mat_data, int bvh_size, __global BVHNodeGPU* bvh,
                         int GI_CHECK, int reset, uint rand, int block, int block_x, int block_y)
{
    int img_width = get_image_width(outputImage);
    int img_height = get_image_height(outputImage);
    int2 pixel = (int2)(get_global_id(0), get_global_id(1));
    
    pixel.x += ceil((float)img_width / block_x) * (block % block_x);
    pixel.y += ceil((float)img_height / block_y) * (block / block_x);
    
    if (pixel.x >= img_width || pixel.y >= img_height)
        return;
    
    //create a camera ray and light ray
    Ray eye_ray, light_ray;
    float r1, r2;
    uint seed = (pixel.y+1)* img_width + (pixel.x+1);
    seed =  rand * seed;
    seed = wang_hash(seed);
    //Since wang_hash can returns 0 and Xor Shift cant handle 0.    
    if(seed == 0)
        seed = wang_hash(seed);
    
    float4 color = (float4) (0.f, 0.f, 0.f, 1.f);
    
    seed = xor_shift(seed);
    r1 = seed / (float) UINT_MAX;
    seed =  xor_shift(seed);
    r2 =  seed / (float) UINT_MAX;
    
    createRay(pixel.x + r1, pixel.y + r2, img_width, img_height, &eye_ray, main_cam);    
    color = shading(pixel, eye_ray, light_ray, GI_CHECK ,&seed, bvh_size, bvh, scene_size, scene_data, mat_data);
   
    if(any(isnan(color)))
            color = PINK;
        
    if ( reset == 1 )
    {   
        color.w = 1;
        write_imagef(outputImage, pixel, color);
    }
    else
    {
        float4 prev_color = read_imagef(inputImage, sampler, pixel);
        int num_passes = prev_color.w;

        color += (prev_color * num_passes);
        color /= (num_passes + 1);
        color.w = num_passes + 1;
        write_imagef(outputImage, pixel, color);    
    }
}

void createRay(float pixel_x, float pixel_y, int img_width, int img_height, Ray* eye_ray, constant Camera* main_cam)
{
    float4 dir;
    float aspect_ratio;
    aspect_ratio = (img_width*1.0)/img_height;

    dir.x = aspect_ratio *((2.0 * pixel_x/img_width) - 1);
    dir.y = (2.0 * pixel_y/img_height) -1 ;
    dir.z = -main_cam->view_plane_dist;
    dir.w = 0;    
    
    eye_ray->dir.x = dot(main_cam->view_mat.r1, dir);
    eye_ray->dir.y = dot(main_cam->view_mat.r2, dir);
    eye_ray->dir.z = dot(main_cam->view_mat.r3, dir);
    eye_ray->dir.w = dot(main_cam->view_mat.r4, dir);
    
    eye_ray->dir = normalize(eye_ray->dir);
    
    eye_ray->origin = (float4) (main_cam->view_mat.r1.w,
                                main_cam->view_mat.r2.w,
                                main_cam->view_mat.r3.w,
                                main_cam->view_mat.r4.w);
                                
    eye_ray->is_shadow_ray = false;
    eye_ray->length = INFINITY;                             
}

bool traceRay(Ray* ray, HitInfo* hit, int bvh_size, __global BVHNodeGPU* bvh, int scene_size, __global Triangle* scene_data)
{
    bool flag = false;
    
    for(int i = 0; i < LIGHT_SIZE; i++)
    {       
        float DdotN = dot(ray->dir, light_sources[i].norm);
        if(fabs(DdotN) > 0.0001)
        {
            float t = dot(light_sources[i].norm, light_sources[i].pos - ray->origin) / DdotN;            
            if(t>0.0 && t < ray->length)
            {
                float proj1, proj2, la, lb;
                float4 temp;
				
                temp = ray->origin + (ray->dir * t);
                temp = temp - light_sources[i].pos;
				proj1 = dot(temp, light_sources[i].edge_l);
				proj2 = dot(temp, light_sources[i].edge_w);
				la = length(light_sources[i].edge_l);
				lb = length(light_sources[i].edge_w);
				
                // Projection of the vector from rectangle corner to hitpoint on the edges.
				proj1 /= la;
				proj2 /= lb;
				
				if( (proj1 >= 0.0 && proj2 >= 0.0)  && (proj1 <= la && proj2 <= lb)  )
				{
                    ray->length = t;
                    hit->hit_point = ray->origin + (ray->dir * t);
					hit->light_ID = i;
                    hit->triangle_ID = -1;
                    flag = true;
				}     
            }
        }       
    }
    //Traverse BVH if present, else brute force intersect all triangles...
    if(bvh_size > 0)
        flag |= traverseBVH(ray, hit, bvh_size, bvh, scene_data);
    else
    {
        for (int i =0 ; i < scene_size; i++)
            flag |= rayTriangleIntersection(ray, hit, scene_data, i);       
    }
    return flag;
}

bool traverseBVH(Ray* ray, HitInfo* hit, int bvh_size, __global BVHNodeGPU* bvh, __global Triangle* scene_data)
{
    int candidate_list[HEAP_SIZE];    
    candidate_list[0] = 0;
    int len = 1;
    bool intersect = false;
    
    if(!rayAabbIntersection(ray, bvh[0].aabb))
        return intersect;
        
    for(int i = 0; i < len && len < HEAP_SIZE; i++)
    {        
        float c_idx = bvh[candidate_list[i]].child_idx;
        if(c_idx == -1 && bvh[candidate_list[i]].vert_len > 0)
        {
            for(int j = 0; j < bvh[candidate_list[i]].vert_len; j++)
            {
                intersect |= rayTriangleIntersection(ray, hit, scene_data, bvh[candidate_list[i]].vert_list[j]);
                //If shadow ray don't need to compute further intersections...
                if(ray->is_shadow_ray && intersect)
                    return true;
            }
            continue;
        }
        
        for(int j = c_idx; j < c_idx + 2; j++)
        {
            AABB bb = {bvh[j].aabb.p_min, bvh[j].aabb.p_max};
            if((bvh[j].vert_len > 0 || bvh[j].child_idx > 0) && rayAabbIntersection(ray, bb))
            {               
                candidate_list[len] = j;
                len++;
            }
        }
    }
    return intersect;
}

bool rayTriangleIntersection(Ray* ray, HitInfo* hit, __global Triangle* scene_data, int idx)
{
    float4 v1v2 = scene_data[idx].v2 - scene_data[idx].v1; 
    float4 v1v3 = scene_data[idx].v3 - scene_data[idx].v1;
    
    float4 pvec = cross(ray->dir, v1v3);
    float det = dot(v1v2, pvec); 
    
    float inv_det = 1.0f/det;
    float4 dist = ray->origin - scene_data[idx].v1;
    float u = dot(pvec, dist) * inv_det;
    
    if(u < 0.0 || u > 1.0f)
        return false;
    
    float4 qvec = cross(dist, v1v2);
    float v = dot(qvec, ray->dir) * inv_det;
    
    if(v < 0.0 || u+v > 1.0)
        return false;
    
    float t = dot(v1v3, qvec) * inv_det;
    
    //BackFace Culling Algo
    /*
    if(det < EPSILON)
        continue;
    
    float4 dist = ray->origin - scene_data[idx].v1;
    float u = dot(pvec, dist);
    
    if(u < 0.0 || u > det)
        continue;
    
    float4 qvec = cross(dist, v1v2);
    float v = dot(qvec, ray->dir);
    
    if(v < 0.0 || u+v > det)
        continue;
    
    float t = dot(v1v3, qvec);
    
    float inv_det = 1.0f/det;
    t *= inv_det;
    u *= inv_det;
    v *= inv_det;*/
    
    if ( t > 0 && t < ray->length ) 
    {
        ray->length = t;                            
        
        float4 N1 = normalize(scene_data[idx].vn1);
        float4 N2 = normalize(scene_data[idx].vn2);
        float4 N3 = normalize(scene_data[idx].vn3);
        
        float w = 1 - u - v;        
        hit->hit_point = ray->origin + ray->dir * t;
        hit->normal = normalize(N1*w + N2*u + N3*v);
        
        hit->triangle_ID = idx;
        hit->light_ID = -1;
        return true;
    }     
    return false;
}

bool rayAabbIntersection(Ray* ray, AABB bb)
{
    float t_max = INFINITY, t_min = -INFINITY;
    float3 dir_inv = 1 / ray->dir.xyz;
    
    float3 min_diff = (bb.p_min - ray->origin).xyz * dir_inv;
    float3 max_diff = (bb.p_max - ray->origin).xyz * dir_inv;
    
    if(!isnan(min_diff.x))
    {
        t_min = fmax(min(min_diff.x, max_diff.x), t_min);
        t_max = min(fmax(min_diff.x, max_diff.x), t_max);
    }
    
    if(!isnan(min_diff.y))
    {
        t_min = fmax(min(min_diff.y, max_diff.y), t_min);
        t_max = min(fmax(min_diff.y, max_diff.y), t_max);
    }
    if(t_max < t_min)
        return false;
    
    if(!isnan(min_diff.z))
    {
        t_min = fmax(min(min_diff.z, max_diff.z), t_min);
        t_max = min(fmax(min_diff.z, max_diff.z), t_max);
    }
    
    /*
    t_min = fmax(t_min, min(min(min_diff.x, max_diff.x), t_max));
    t_max = min(t_max, fmax(fmax(min_diff.x, max_diff.x), t_min));

    t_min = fmax(t_min, min(min(min_diff.y, max_diff.y), t_max));
    t_max = min(t_max, fmax(fmax(min_diff.y, max_diff.y), t_min));

    t_min = fmax(t_min, min(min(min_diff.z, max_diff.z), t_max));
    t_max = min(t_max, fmax(fmax(min_diff.z, max_diff.z), t_min));*/
    
    return (t_max > fmax(t_min, 0.0f));
}

void createLightPath(PathInfo* light_path, int* path_length, uint* seed, int bvh_size, __global BVHNodeGPU* bvh, int scene_size, __global Triangle* scene_data, __global Material* mat_data)
{
    Ray light_ray;    
    HitInfo hit = {-1, -1, (float4)(0,0,0,1), light_sources[0].norm};
	float pdf = 1;
    
    *seed = xor_shift(*seed);
    float r1 = *seed / (double) UINT_MAX;	
	*seed = xor_shift(*seed);
    float r2 = *seed / (float) UINT_MAX; 
     
    float4 A = light_sources[0].edge_l * r2;
	float4 B = light_sources[0].edge_w * r1;
	hit.hit_point = (A + B) + light_sources[0].pos;
    hit.normal = light_sources[0].norm;
    
    //Setup Light Vertex
    light_path[0].hit_info = hit;
    light_path[0].hit_info.light_ID = 0;
    float area = length(light_sources[0].edge_l) * length(light_sources[0].edge_w);
    light_path[0].fwd_pdf = 1.0f / area;
    light_path[0].rev_pdf = 1.0;        //For Use in MIS later on..
    light_path[0].contrib = light_sources[0].ke / light_path[0].fwd_pdf;
    
    cosineWeightedHemisphere(&light_ray, &pdf, hit, seed); 
       
    if(pdf <= 0.0f || !traceRay(&light_ray, &hit, bvh_size, bvh, scene_size, scene_data) || hit.light_ID >= 0)
        return;  
    
    //Setup Vertex after light
    light_path[1].hit_info = hit;
    light_path[1].dir = light_ray.dir;
    light_path[1].fwd_pdf = pdf;
    light_path[1].rev_pdf = 1.0f;
    light_path[1].contrib =  max(0.0f, dot(light_path[0].hit_info.normal, light_path[1].dir )) / pdf;
    light_path[1].contrib *=  light_path[0].contrib;
    
    float r = 0.0;
    float brdf_prob = 0.0f;
    (*path_length)++;
    
    for(int i = 2; i < BDPT_BOUNCES; i++)
    {
        
        bool is_glossy_bounce = sampleGlossyPdf(hit, scene_data, mat_data, seed, &brdf_prob);        
        if(brdf_prob == 0.0f)
            break;
        
        if(is_glossy_bounce)
            phongSampleHemisphere(&light_ray, &pdf, -light_path[i-1].dir, hit, seed, scene_data, mat_data);
        else
            cosineWeightedHemisphere(&light_ray, &pdf, hit, seed); 
        
        if(!traceRay(&light_ray, &hit, bvh_size, bvh, scene_size, scene_data) || hit.light_ID >= 0 || pdf <= 0.0f)
            break;                
        (*path_length)++;
        light_path[i].hit_info = hit; 
        light_path[i].dir = light_ray.dir;
        
        light_path[i].fwd_pdf = pdf; 
        light_path[i].rev_pdf = 1.0;
           
        light_path[i].contrib = evaluateBRDF(-light_path[i-1].dir, light_path[i].dir, light_path[i-1].hit_info, is_glossy_bounce, brdf_prob, scene_data, mat_data)
                                * fmax(0.0f, dot(light_path[i].dir, light_path[i-1].hit_info.normal));
        light_path[i].contrib /= pdf;
        
        light_path[i].contrib *=  light_path[i-1].contrib;
        if(i > RR_THRESHOLD)
        {
            *seed = xor_shift(*seed);
            r = *seed / (float) UINT_MAX;
            float p = min(getYluminance(light_path[i].contrib), 0.95f);
            if(r >= p)
                break;
            else
             light_path[i].contrib *= 1.0f/p;
        }
        
    }
}

void createEyePath(PathInfo* eye_path, int* path_length, Ray eye_ray, uint* seed, int bvh_size, __global BVHNodeGPU* bvh, int scene_size, __global Triangle* scene_data, __global Material* mat_data)
{
    HitInfo hit = {-1,-1, (float4)(0,0,0,1), (float4)(0,0,0,0)};
    
    eye_path[0].hit_info = hit;
    if(!traceRay(&eye_ray, &eye_path[0].hit_info,  bvh_size, bvh, scene_size, scene_data))    
        return;    
    
    eye_path[0].dir = eye_ray.dir;
    eye_path[0].fwd_pdf = 1.0f;
    eye_path[0].contrib = 1.0f;
    
    float pdf = 1, brdf_prob = 0.0f, r;
    for(int i = 1; i < BDPT_BOUNCES; i++)
    {        
        bool is_glossy_bounce = sampleGlossyPdf(eye_path[i-1].hit_info, scene_data, mat_data, seed, &brdf_prob);        
        if(brdf_prob == 0.0f)
            break;
        
        if(is_glossy_bounce)
            phongSampleHemisphere(&eye_ray, &pdf, -eye_path[i-1].dir, eye_path[i-1].hit_info, seed, scene_data, mat_data);
        else
            cosineWeightedHemisphere(&eye_ray, &pdf, eye_path[i-1].hit_info, seed);             
        
        if(pdf <= 0.0f || !traceRay(&eye_ray, &hit, bvh_size, bvh, scene_size, scene_data) || hit.light_ID >= 0)
            break;
        
        (*path_length)++;
         
        eye_path[i].hit_info = hit;
        eye_path[i].dir = eye_ray.dir;        
        eye_path[i].fwd_pdf = pdf;
        eye_path[i].contrib = evaluateBRDF(eye_path[i].dir, -eye_path[i-1].dir, eye_path[i-1].hit_info, is_glossy_bounce, brdf_prob, scene_data, mat_data)
                                * max(0.0f, dot(eye_path[i].dir, eye_path[i-1].hit_info.normal));
        eye_path[i].contrib /= pdf;
        eye_path[i].contrib *= eye_path[i-1].contrib;        
        if(i > RR_THRESHOLD)
        {
            *seed = xor_shift(*seed);
            r = *seed / (float) UINT_MAX;
            float p = min(getYluminance(eye_path[i].contrib), 0.95f);
            if(r >= p)
                break;
            else
                eye_path[i].contrib *= 1.0f/p;
        }
    }    
}

float4 shading(int2 pixel, Ray ray, Ray light_ray, int GI_CHECK, uint* seed, int bvh_size, __global BVHNodeGPU* bvh, int scene_size, __global Triangle* scene_data, __global Material* mat_data)
{   
    PathInfo light_path[BDPT_BOUNCES], eye_path[BDPT_BOUNCES];
    int lp_len = 1, ep_len = 1; 
    
    createLightPath(light_path, &lp_len, seed, bvh_size, bvh, scene_size, scene_data, mat_data);
    createEyePath(eye_path, &ep_len, ray, seed, bvh_size, bvh, scene_size, scene_data, mat_data);
    
    if(eye_path[0].hit_info.light_ID >= 0)
    {
        if(dot(ray.dir, light_sources[eye_path[0].hit_info.light_ID].norm) < 0)
            return (float4)(1,1,1,1);
        else
            return (float4)(0.1, 0.1, 0.1, 1);
    }
    else if (eye_path[0].hit_info.triangle_ID < 0 )
        return BACKGROUND_COLOR;
    
    float4  eye_path_color, throughput, color, subpaths_color; 
    throughput = (float4) (1.f, 1.f, 1.f, 1.f);
    eye_path_color = (float4) (0.f, 0.f, 0.f, 1.f);   
    color = (float4) (0.f, 0.f, 0.f, 1.f);
    float eye_path_weight = 1.0, ks = 0.0;
    
    for(int i = 0; i< ep_len; i++)
    {
        if(eye_path_weight == 0)
            break;
        
        subpaths_color = (float4) (0.f, 0.f, 0.f, 1.f);
        float4 spec_color = mat_data[scene_data[eye_path[i].hit_info.triangle_ID].matID].ks;
        float4 emission = mat_data[scene_data[eye_path[i].hit_info.triangle_ID].matID].ke;
        ks =  max(max(spec_color.x, max(spec_color.y, spec_color.z)), 0.1f); 
        
        throughput = eye_path[i].contrib;        
        color += throughput * (emission + evaluateDirectLighting(pixel, -eye_path[i].dir, eye_path[i].hit_info, seed, bvh_size, bvh, scene_size, scene_data, mat_data)) * eye_path_weight; 
        for(int j = lp_len-1; j>0; j--)
        { 
            Ray determ_ray;
            HitInfo determ_hit = {-1, -1, (float4)(0,0,0,1), (float4)(0,0,0,0)};
            float4 throughput_lp = (float4)(1.0f);
            
            determ_ray.dir = normalize(light_path[j].hit_info.hit_point - eye_path[i].hit_info.hit_point);            
            determ_ray.origin = eye_path[i].hit_info.hit_point + determ_ray.dir * EPSILON;
            float dist =  length(light_path[j].hit_info.hit_point - eye_path[i].hit_info.hit_point);
            dist *= dist;            
            
            determ_ray.length = length(light_path[j].hit_info.hit_point - determ_ray.origin);
            determ_ray.is_shadow_ray = true;
            
            if(dot(determ_ray.dir, eye_path[i].hit_info.normal) <= 0 || dot(-determ_ray.dir, light_path[j].hit_info.normal) <= 0)
                continue;
            
            if(!traceRay(&determ_ray, &determ_hit, bvh_size, bvh, scene_size, scene_data) )            
            {             
                throughput_lp = light_path[j].contrib;
                float4 w_i = determ_ray.dir;
                float4 w_o = -eye_path[i].dir;
                HitInfo hit = eye_path[i].hit_info;
                
                float gf = max(dot(w_i, hit.normal), 0.0f) * max(dot(-w_i, light_path[j].hit_info.normal), 0.0f) / dist;
                float prob = 0.0f;
                
                bool sample_glossy_bounce = sampleGlossyPdf(hit, scene_data, mat_data, seed, &prob);                
                float4 eye_to_light_brdf = evaluateBRDF(w_i, w_o, hit, sample_glossy_bounce, prob, scene_data, mat_data);
                
                sample_glossy_bounce = sampleGlossyPdf(light_path[j].hit_info, scene_data, mat_data, seed, &prob);
                float4 light_to_eye_brdf = evaluateBRDF(-light_path[j].dir, -w_i, light_path[j].hit_info, sample_glossy_bounce, prob, scene_data, mat_data);
                
                throughput_lp *=  gf * eye_to_light_brdf * light_to_eye_brdf;
                throughput_lp *= throughput;
                subpaths_color += throughput_lp;
            }            
        }
        color += subpaths_color * ( eye_path_weight *  (1 - ks));        
        eye_path_weight = eye_path_weight * ks;
    }
    return color;
}

float4 evaluateDirectLighting(int2 pixel , float4 w_o, HitInfo hit, uint* seed, int bvh_size, __global BVHNodeGPU* bvh, int scene_size, __global Triangle* scene_data,  __global Material* mat_data)
{
    float4 emission = mat_data[scene_data[hit.triangle_ID].matID].ke;
    float4 light_sample = (float4) (0.f, 0.f, 0.f, 0.f);
    float4 w_i;
    float light_pdf, brdf_prob = 0.0f; 
    bool sample_glossy = false;
    
    int j = sampleLights(hit, &light_pdf, &w_i, seed);
	if(j == -1 || light_pdf <= 0.0f)
		return emission;
	
	float len = length(w_i);
    len -= EPSILON * 1.5f;
    w_i = normalize(w_i);
    
	Ray shadow_ray = {hit.hit_point + w_i * EPSILON, w_i, INFINITY, true};
	HitInfo shadow_hitinfo = {-1, -1, (float4)(0,0,0,1), (float4)(0,0,0,0)};
    shadow_ray.length = len; 
    
    //Direct Light Sampling     
	//If ray doesn't hit anything (exclude light source j while intersection check). This means light source j visible.
    if(!traceRay(&shadow_ray, &shadow_hitinfo, bvh_size, bvh, scene_size, scene_data))
    {
        sample_glossy = sampleGlossyPdf(hit, scene_data, mat_data, seed, &brdf_prob);
        if(brdf_prob == 0.0f)
            return emission;
		light_sample = evaluateBRDF(w_i, w_o, hit, sample_glossy, brdf_prob, scene_data, mat_data) * light_sources[j].ke * fmax(dot(w_i, hit.normal), 0.0f);
		light_sample *= 1/light_pdf;
	}
	
    #ifndef MIS    
	return light_sample + emission;
    
    //We use MIS with Power Heuristic. The exponent can be set to 1 for balance heuristic.   
	#else
    float4 brdf_sample = (float4) (0.f, 0.f, 0.f, 0.f);
    float brdf_pdf, mis_weight;
    
    //Compute MIS weighted Light sample
    if(sample_glossy)
        brdf_pdf = calcPhongPDF(w_i, w_o, hit, scene_data, mat_data);
    else
        brdf_pdf = calcCosPDF(w_i, hit.normal);
    
    mis_weight =  light_pdf;     
    powerHeuristic(&mis_weight, light_pdf, brdf_pdf, 2);
    light_sample *= mis_weight;
    
    // BRDF Sampling
    Ray brdf_sample_ray;
    
    if(sample_glossy)
        phongSampleHemisphere(&brdf_sample_ray, &brdf_pdf, w_o, hit, seed, scene_data, mat_data);
    else
        cosineWeightedHemisphere(&brdf_sample_ray, &brdf_pdf, hit, seed);
    
    if(brdf_pdf <= 0.0f)
        return light_sample + emission;                
    
    w_i = brdf_sample_ray.dir;  
    HitInfo new_hitinfo = {-1, -1, (float4)(0,0,0,1), (float4)(0,0,0,0)};   
    
    //If traceRay doesnt hit anything or if it does not hit the same light source return only light sample.
    if(!traceRay(&brdf_sample_ray, &new_hitinfo, bvh_size, bvh, scene_size, scene_data) || new_hitinfo.light_ID != j)
       return light_sample + emission;
    
    mis_weight = brdf_pdf;
    powerHeuristic(&mis_weight, light_pdf, brdf_pdf, 2);
    brdf_sample =  evaluateBRDF(w_i, w_o, hit, sample_glossy, brdf_prob, scene_data, mat_data) * light_sources[j].ke * fmax(dot(w_i, hit.normal), 0.0f);
    brdf_sample *=  mis_weight / brdf_pdf;
    
    return (light_sample + brdf_sample + emission);
    #endif
}

float4 evaluateBRDF(float4 w_i, float4 w_o, HitInfo hit_info, bool sample_glossy, float rr_prob, __global Triangle* scene_data, __global Material* mat_data)
{
    float4 color, refl_vec;
    float cos_alpha;    
    
    refl_vec = (2*dot(w_i, hit_info.normal)) * hit_info.normal - w_i;
    refl_vec = normalize(refl_vec);
    
    int matID = scene_data[hit_info.triangle_ID].matID;
    
    if(!sample_glossy)
        color = mat_data[matID].kd * INV_PI / rr_prob;
    else
    {
        cos_alpha = pow(fmax(dot(w_o, refl_vec), 0.0f), mat_data[matID].px + mat_data[matID].py);      
        int phong_exp = mat_data[matID].px + mat_data[matID].py;
        color = mat_data[matID].ks * cos_alpha * (phong_exp + 2) * INV_PI * 0.5f / rr_prob;
    }        
    return color;    
}

int sampleLights(HitInfo hit_info, float* light_pdf, float4* w_i, uint* seed)
{
    float sum = 0, cosine_falloff = 0, r1, r2, distance, area;  // sum = sum of geometry terms.
    float weights[LIGHT_SIZE];                                  // array of weights for each light source.
    float4 w_is[LIGHT_SIZE];                                    // Store every light direction. Store this to return information about the light source picked.
    for(int i = 0; i < LIGHT_SIZE; i++)
    {
        float4 temp_wi;
        
        *seed = xor_shift(*seed);
        r1 = *seed / (float) UINT_MAX;      
        *seed = xor_shift(*seed);   
        r2 = *seed / (float) UINT_MAX;
        
        temp_wi = (light_sources[i].pos + r1*light_sources[i].edge_l + r2*light_sources[i].edge_w) - hit_info.hit_point;    
        distance = dot(temp_wi, temp_wi);
        
        w_is[i] = temp_wi;  
        temp_wi = normalize(temp_wi);        
        
        cosine_falloff = max(dot(temp_wi, hit_info.normal), 0.0f) * max(dot(-temp_wi, light_sources[i].norm), 0.0f);
        
        if(cosine_falloff <= 0.0)
        {
            weights[i] = 0;
            continue;
        }
        area = length(light_sources[i].edge_l) * length(light_sources[i].edge_w);
        
        if(LIGHT_SIZE == 1)
        {
            *w_i = w_is[i];
            *light_pdf = 1/area;
            *light_pdf *= distance / fmax(dot(-temp_wi, light_sources[i].norm), 0.0f);
            return i;
        }
        
        weights[i] = length(light_sources[i].ke) * cosine_falloff * area/ distance;
        sum += weights[i]; 
    }
    
    // If no lights get hit, return -1
    if(sum == 0)
        return -1;
    
    //Pick a Uniform random number and return the light w.r.t to it's probability.
    *seed = xor_shift(*seed);
    r1 = *seed / (float) UINT_MAX;
    
    float cumulative_weight = 0;
    for(int i = 0; i < LIGHT_SIZE; i++)
    {       
        float weight = weights[i]/sum;
        
        if(r1 >= cumulative_weight && r1 < (cumulative_weight + weight ) )
        {
            area = length(light_sources[i].edge_l) * length(light_sources[i].edge_w);            
            *w_i = w_is[i];
            *light_pdf = (weight/area);
            
            //Convert PDF w.r.t area measure to PDF w.r.t solid angle. MIS needs everything to be in the same domain (either dA or dw)
            *light_pdf *=  (dot(*w_i, *w_i) / (fmax(dot(-normalize(*w_i), light_sources[i].norm), 0.0f) ));
            return i;
        }
        cumulative_weight += weight;
    }
}

void phongSampleHemisphere (Ray* ray, float* pdf, float4 w_i, HitInfo hit_info, uint* seed, __global Triangle* scene_data, __global Material* mat_data)
{
    /* Create a new coordinate system for Normal Space where Z aligns with Reflection Direction. */
    Mat4x4 normal_to_world;
    float4 Ny, Nx, Nz;
    
    // w_i is the inverse of the direction to the current surface.
    Nz = 2*(dot(w_i, hit_info.normal)) * hit_info.normal - w_i;
    Nz = normalize(Nz);

    if ( fabs(Nz.y) > fabs(Nz.z) )
        Nx = (float4) (Nz.y, -Nz.x, 0, 0.f);
    else
        Nx = (float4) (Nz.z, 0, -Nz.x, 0.f);

    Nx = normalize(Nx);
    Ny = normalize(cross(Nz, Nx));

    normal_to_world.r1 = (float4) (Nx.x, Ny.x, Nz.x, hit_info.hit_point.x);
    normal_to_world.r2 = (float4) (Nx.y, Ny.y, Nz.y, hit_info.hit_point.y);
    normal_to_world.r3 = (float4) (Nx.z, Ny.z, Nz.z, hit_info.hit_point.z);
    normal_to_world.r4 = (float4) (Nx.w, Ny.w, Nz.w, hit_info.hit_point.w);

    float x, y, z, r1, r2;

    *seed = xor_shift(*seed);
    r1 = *seed / (float) UINT_MAX;
    *seed = xor_shift(*seed);
    r2 = *seed / (float) UINT_MAX;

    /*
    theta = inclination (from Z), phi = azimuth. Need theta in [0, pi/2] and phi in [0, 2pi]
    => X = r sin(theta) cos(phi)
    => Y = r sin(theta) sin(phi)
    => Z = r cos(theta)

    Phong PDF is  (n+1) * cos^n(alpha)/2pi  where alpha is the angle between reflection dir and w_o(the new ray being sampled).
    Since reflection direction aligned with Z axis, alpha equals theta. Formula is,

    (alpha, phi) = (acos(r1^(1/(n+1))), 2pi*r2)
    */
    int phong_exponent;
    int matID = scene_data[hit_info.triangle_ID].matID;
    phong_exponent = mat_data[matID].px + mat_data[matID].py;

    float phi = 2*PI * r2;
    float costheta = pow(r1, 1.0f/(phong_exponent+1));
    float sintheta = 1 - pow(r1, 2.0f/(phong_exponent+1));
    sintheta = sqrt(sintheta);

    x = sintheta * cos(phi);  // r * sin(theta) cos(phi)
    y = sintheta * sin(phi);  // r * sin(theta) sin(phi)
    z = costheta;             // r * cos(theta)  r = 1

    float4 ray_dir = (float4) (x, y, z, 0);

    ray->dir.x = dot(normal_to_world.r1, ray_dir);
    ray->dir.y = dot(normal_to_world.r2, ray_dir);
    ray->dir.z = dot(normal_to_world.r3, ray_dir);
    ray->dir.w = 0;

    ray->dir = normalize(ray->dir);
    ray->origin = hit_info.hit_point + ray->dir * EPSILON;
    ray->is_shadow_ray = false;
    ray->length = INFINITY;
    
    //If a ray was sampled in the lower hemisphere, set pdf = 0
    if(dot(ray->dir, hit_info.normal) < 0)
        *pdf = 0;
    else
        *pdf = (phong_exponent+1) * 0.5 * INV_PI * pow(costheta, phong_exponent);
}

void uniformSampleHemisphere(Ray* ray, float* pdf, HitInfo hit_info, uint* seed)
{

    /* Create a new coordinate system for Normal Space where Z aligns with normal. */
    Mat4x4 normal_to_world;
    float4 Ny, Nx, Nz;
    Nz = hit_info.normal;

    if ( fabs(Nz.y) > fabs(Nz.z) )
        Nx = (float4) (Nz.y, -Nz.x, 0, 0.f);
    else
        Nx = (float4) (Nz.z, 0, -Nz.x, 0.f);

    Nx = normalize(Nx);
    Ny = normalize(cross(Nz, Nx));

    normal_to_world.r1 = (float4) (Nx.x, Ny.x, Nz.x, hit_info.hit_point.x);
    normal_to_world.r2 = (float4) (Nx.y, Ny.y, Nz.y, hit_info.hit_point.y);
    normal_to_world.r3 = (float4) (Nx.z, Ny.z, Nz.z, hit_info.hit_point.z);
    normal_to_world.r4 = (float4) (Nx.w, Ny.w, Nz.w, hit_info.hit_point.w);

    float x, y, z, r1, r2;
    /* Sample hemisphere according to area.  */
    *seed = xor_shift(*seed);
    r1 = *seed / (float) UINT_MAX;
    *seed = xor_shift(*seed);
    r2 = *seed / (float) UINT_MAX;

    /*
    theta = inclination (from Z), phi = azimuth. Need theta in [0, pi/2] and phi in [0, 2pi]
    => X = r sin(theta) cos(phi)
    => Y = r sin(theta) sin(phi)
    => Z = r cos(theta)

    For uniformly sampling w.r.t area, we have to take into account
    theta since Area varies according to it. Remeber dA = r^2 sin(theta) d(theta) d(phi)
    The PDF is constant and equals 1/2pi

    According to that we have the CDF for theta as
    => cos(theta) = 1 - r1    ----- where "r1" is a uniform random number in range [0,1]

    We can also simplify if we want.....
    => cos(theta) = r1     -------- since r1 is uniform in the range [0,1], (r1) and (1-r1) have the same probability.

    From there we can directly find sin(theta) instead of using inverse transform sampling to avoid expensive trigonometric functions.
    => sin(theta) = sqrt[ 1-cos^2(theta) ]
    => sin(theta) = sqrt[ 1 - r1^2 ]

    */

    float phi = 2*PI * r2;
    float sinTheta = sqrt(1 - r1*r1);   // uniform
    x = sinTheta * cos(phi);  // r * sin(theta) cos(phi)
    y = sinTheta * sin(phi);  // r * sin(theta) sin(phi)
    z = r1;             // r * cos(theta)  r = 1

    float4 ray_dir = (float4) (x, y, z, 0);
    ray->dir.x = dot(normal_to_world.r1, ray_dir);
    ray->dir.y = dot(normal_to_world.r2, ray_dir);
    ray->dir.z = dot(normal_to_world.r3, ray_dir);
    ray->dir.w = 0;

    ray->dir = normalize(ray->dir);
    ray->origin = hit_info.hit_point + ray->dir * EPSILON;
    ray->is_shadow_ray = false;
    ray->length = INFINITY;

    *pdf = 2* PI;
}

void cosineWeightedHemisphere(Ray* ray, float* pdf, HitInfo hit_info, uint* seed)
{
    /* Create a new coordinate system for Normal Space where Z aligns with normal. */
    Mat4x4 normal_to_world;
    float4 Ny, Nx, Nz;
    Nz = hit_info.normal;
    
    if ( fabs(Nz.y) > fabs(Nz.z) )
        Nx = (float4) (Nz.y, -Nz.x, 0, 0.f);
    else
        Nx = (float4) (Nz.z, 0, -Nz.x, 0.f);

    Nx = normalize(Nx);
    Ny = normalize(cross(Nz, Nx));

    normal_to_world.r1 = (float4) (Nx.x, Ny.x, Nz.x, hit_info.hit_point.x);
    normal_to_world.r2 = (float4) (Nx.y, Ny.y, Nz.y, hit_info.hit_point.y);
    normal_to_world.r3 = (float4) (Nx.z, Ny.z, Nz.z, hit_info.hit_point.z);
    normal_to_world.r4 = (float4) (Nx.w, Ny.w, Nz.w, hit_info.hit_point.w);

    float x, y, z, r1, r2;

    *seed = xor_shift(*seed);
    r1 = *seed / (float) UINT_MAX;
    *seed = xor_shift(*seed);
    r2 = *seed / (float) UINT_MAX;

    /*
    theta = inclination (from Z), phi = azimuth. Need theta in [0, pi/2] and phi in [0, 2pi]
    => X = r sin(theta) cos(phi)
    => Y = r sin(theta) sin(phi)
    => Z = r cos(theta)

    For cosine weighted sampling we have the PDF
    PDF = cos(theta)/pi
    Our equation then becomes,
    1/pi {double integral}{cos(theta) sin(theta) d(theta) d(phi)} = 1

    According to that we have the CDF for theta as
    => sin^2(theta) = r1    ----- where "r1" is a uniform random number in range [0,1]
    => sin(theta) = root(r1)
    => cos(theta) = root(1-r1)

    The CDF for phi is given as,
    => phi/2pi = r2
    => phi = 2 * pi * r2
    */
    
    
    float phi = 2 * PI * r2;
    float sinTheta = sqrt(r1);
    x = sinTheta * cos(phi);  // r * sin(theta) cos(phi)
    y = sinTheta * sin(phi);  // r * sin(theta) sin(phi)
    z = sqrt(1-r1);             // r * cos(theta),  r = 1

    float4 ray_dir = (float4) (x, y, z, 0);
    ray->dir.x = dot(normal_to_world.r1, ray_dir);
    ray->dir.y = dot(normal_to_world.r2, ray_dir);
    ray->dir.z = dot(normal_to_world.r3, ray_dir);
    ray->dir.w = 0;

    ray->dir = normalize(ray->dir);
    ray->origin = hit_info.hit_point + ray->dir * EPSILON;
    ray->is_shadow_ray = false;
    ray->length = INFINITY;

    *pdf = z * INV_PI;
}

float convertPdfAngleToPdfArea(float pdf_angle, HitInfo curr, HitInfo next)
{
    float pdf_area;
    float4 dir = next.hit_point - curr.hit_point;    
    float dist = length(dir) * length(dir);
    dir = normalize(dir);
    pdf_area = pdf_angle * fmax(0.0f, dot(next.normal, -dir)) / dist ;
    return pdf_area;    
}

float calcPhongPDF(float4 w_i, float4 w_o, HitInfo hit_info, __global Triangle* scene_data, __global Material* mat_data)
{
    float4 refl_dir;
    refl_dir = 2*(dot(w_o, hit_info.normal)) * hit_info.normal - w_o;
    refl_dir = normalize(refl_dir);
    
    float costheta = fmax(0.0f, cos(dot(refl_dir, w_i)));
    float phong_exponent;
    int matID = scene_data[hit_info.triangle_ID].matID;
    phong_exponent = mat_data[matID].px + mat_data[matID].py;
    
    return (phong_exponent+1) * 0.5 * INV_PI * pow(costheta, phong_exponent);    
}

float calcCosPDF(float4 w_i, float4 normal)
{
    return fmax(dot(w_i, normal), 0.0f) * INV_PI;
}

bool sampleGlossyPdf(HitInfo hit, __global Triangle* scene_data, __global Material* mat_data, uint* seed, float* prob)
{
    *seed = xor_shift(*seed);
    float r = *seed / (float) UINT_MAX;  
    
    float4 ks, kd, sum;
    float pd, ps; 
    
    ks = mat_data[scene_data[hit.triangle_ID].matID].ks;
    kd = mat_data[scene_data[hit.triangle_ID].matID].kd;
    
    if(length(ks.xyz) == 0.0f)
    {
        *prob = 1.0f;
        return false;        
    }
    else if(length(kd.xyz) == 0.0f || kd.x + kd.y + kd.z == 0.0f)
    {
        *prob = 1.0f;
        return true;        
    }
    
    sum = ks + kd;
    float max_val = max(sum.x, max(sum.y, sum.z));
    
    if(max_val == sum.x)
    {
        pd = kd.x;
        ps = ks.x;
    }
    else if(max_val == sum.y)
    {
        pd = kd.y;
        ps = ks.y;
    }
    else
    {
        pd = kd.z;
        ps = ks.z;
    }
    
    if(max_val < 1.0f)
    {
        pd += (1 - max_val)/2.0f;
        ps += (1 - max_val)/2.0f;
    }
    
    if(r < pd)
    {
        *prob = pd;
        return false;
    }
    else
    {
        *prob = ps;
        return true;        
    }
}


float getYluminance(float4 color)
{
    return 0.212671f*color.x + 0.715160f*color.y + 0.072169f*color.z;
}

float4 inverseGammaCorrect(float4 color)
{
    return pow(color, (float4) 2.2f);
}

uint wang_hash(uint seed)
{
    seed = (seed ^ 61) ^ (seed >> 16);
    seed *= 9;
    seed = seed ^ (seed >> 4);
    seed *= 0x27d4eb2d;
    seed = seed ^ (seed >> 15);
    return seed;
}

uint xor_shift(uint seed)
{
    seed ^= seed << 13;
    seed ^= seed >> 17;
    seed ^= seed << 5;
    return seed;
}

void powerHeuristic(float* weight, float pdf1, float pdf2, int beta)
{
    *weight = (pown(*weight, beta)) / (pown(pdf1, beta) + pown(pdf2, beta) );  
}