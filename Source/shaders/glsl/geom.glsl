//Segment
float distanceToSegment(vec2 a, vec2 b, vec2 p, out float fp){
	vec2 d = p - a;
	vec2 x = b - a;

	fp = 0.0; //fractional projection, 0 - 1 in the length of vec2(b - a)
	float lx = length(x);
	
	if(lx <= 0.0001) return length(d);//#! needs improving; hot fix for normalization of 0 vector

	float projection = dot(d, x / lx); //projection in pixel units

	fp = projection / lx;

	if(projection < 0.0)            return length(d);
	else if(projection > length(x)) return length(p - b);
	return sqrt(abs(dot(d,d) - projection*projection));
}
float distanceToSegment(vec2 a, vec2 b, vec2 p){
	float fp;
	return distanceToSegment(a, b, p, fp);
}