#ifdef GL_OES_standard_derivatives
    #extension GL_OES_standard_derivatives : enable
#endif  

uniform bool u_showIntersection;
uniform bool u_showThroughEllipsoid;

uniform float u_sensorRadius;

varying vec3 v_positionWC;
varying vec3 v_positionEC;
varying vec3 v_normalEC;

vec4 getColor(float sensorRadius, vec3 pointEC)
{
    czm_materialInput materialInput;
    
    vec3 pointMC = (czm_inverseModelView * vec4(pointEC, 1.0)).xyz;                                
    materialInput.st = sensor2dTextureCoordinates(sensorRadius, pointMC);   
    materialInput.str = pointMC / sensorRadius;
    
    vec3 positionToEyeEC = -v_positionEC;
    materialInput.positionToEyeEC = positionToEyeEC;
    
    vec3 normalEC = normalize(v_normalEC);
    normalEC = mix(normalEC, -normalEC, step(normalEC.z, 0.0));  // Normal facing viewer
    materialInput.normalEC = normalEC;
    
    czm_material material = czm_getMaterial(materialInput);
    return czm_phong(normalize(positionToEyeEC), material);
}

bool isOnBoundary(float value, float epsilon)
{
    float width = 4.0;  // TODO: Expose as a uniform
    float tolerance = width * epsilon;

#ifdef GL_OES_standard_derivatives
    float delta = max(abs(dFdx(value)), abs(dFdy(value)));
    float temp = abs(value);
    return temp < tolerance || temp - delta < tolerance;
#else
    return abs(value) < tolerance;
#endif
}

vec4 shade(bool isOnBoundary)
{
    if (u_showIntersection && isOnBoundary)
    {
        return getIntersectionColor();
    }
    return getColor(u_sensorRadius, v_positionEC);
}

float ellipsoidSurfaceFunction(czm_ellipsoid ellipsoid, vec3 point)
{
    vec3 scaled = ellipsoid.inverseRadii * point;
    return dot(scaled, scaled) - 1.0;
}

void main()
{
    vec3 sensorVertexWC = czm_model[3].xyz;      // (0.0, 0.0, 0.0) in model coordinates
    vec3 sensorVertexEC = czm_modelView[3].xyz;  // (0.0, 0.0, 0.0) in model coordinates

    czm_ellipsoid ellipsoid = czm_getWgs84EllipsoidEC();
    float ellipsoidValue = ellipsoidSurfaceFunction(ellipsoid, v_positionWC);

    // Occluded by the ellipsoid?
	if (!u_showThroughEllipsoid)
	{
	    // Discard if in the ellipsoid    
	    // PERFORMANCE_IDEA: A coarse check for ellipsoid intersection could be done on the CPU first.
	    if (ellipsoidValue < 0.0)
	    {
            discard;
	    }

	    // Discard if in the sensor's shadow
	    if (inSensorShadow(sensorVertexWC, ellipsoid, v_positionWC))
	    {
	        discard;
	    }
    }

    // Discard if not in the sensor's sphere
    // PERFORMANCE_IDEA: We can omit this check if the radius is Number.POSITIVE_INFINITY.
    if (distance(v_positionEC, sensorVertexEC) > u_sensorRadius)
    {
        discard;
    }
    
    // TODO: Each surface functions should have an associated tolerance based on the floating point error.
    bool isOnEllipsoid = isOnBoundary(ellipsoidValue, czm_epsilon3);
    gl_FragColor = shade(isOnEllipsoid);
}
