[Begin_ResourceLayout]

[directives:Kind BASE PULSE]
[directives:Multiview MULTIVIEW_OFF MULTIVIEW]

	cbuffer Base : register(b0)
	{
		float4x4 ViewProj		    : packoffset(c0);	[ViewProjection]
		float4x4 World				: packoffset(c4);	[World]
		float Time					: packoffset(c8.x); [Time]
	};

	cbuffer Matrices : register(b1)
	{
		float3 EdgeColor		: packoffset(c0.x); [Default(1,1,1)]
		float EdgeWidth			: packoffset(c0.w); [Default(0.01)]
		float3 FillColor0		: packoffset(c1.x); [Default(0.613, 0.507, 0.953)]
		float EdgeSmooth		: packoffset(c1.w); [Default(0.08)]
		float3 FillColor1		: packoffset(c2.x); [Default(0.234, 0.527, 0.988)]
		float Displacement		: packoffset(c2.w); [Default(0.2)]
		float tPosY             : packoffset(c3.x); [Default(0)]
		float distorsionH       : packoffset(c3.y); [Default(2)]
	};

	cbuffer PerCamera : register(b2)
	{
		float4x4  MultiviewViewProj[2]		: packoffset(c0.x);  [StereoCameraViewProjection]
		int       EyeCount                  : packoffset(c10.x); [StereoEyeCount]
	};

[End_ResourceLayout]

[Begin_Pass:Default]

	[profile 11_0]
	[entrypoints VS=VS GS=GS PS=PS]

	struct VS_IN
	{
		float4 Position : POSITION;
		
#if MULTIVIEW
		uint InstId : SV_InstanceID;
#endif
	};

	struct GS_IN
	{
		float4 pos 		: SV_POSITION;
		float4 worldPos : TEXCOORD0;
		
#if MULTIVIEW
		uint InstId         : SV_RenderTargetArrayIndex;
#endif
	};
	
	struct PS_IN
	{
		float4 pos 		: SV_POSITION;
		float4 info 	: TEXCOORD0;
		float4 extra	: TEXCOORD1;
		
#if MULTIVIEW
		uint ViewId         : SV_RenderTargetArrayIndex;
#endif		
	};

	//Helpers Functions

	uint XorShift(inout uint state)
	{
		state ^= state << 13;
		state ^= state >> 17;
		state ^= state << 15;
		return state;
	}

	float RandomFloat(inout uint state)
	{
		return XorShift(state) * (1.f / 4294967296.f);
	}
	
#if PULSE
	float InCirc(float x)
	{
		return 1 - sqrt(1 - pow(x, 2));
	}
	
	float OutCirc(float x)
	{
		return sqrt(1 - pow(x - 1, 2));
	}
	
	inline float3 GetNormal(GS_IN input[3])
	{
		float3 a = input[0].worldPos.xyz - input[1].worldPos.xyz;
		float3 b = input[2].worldPos.xyz - input[1].worldPos.xyz;
		return normalize(cross(a, b));
	}
#endif

	GS_IN VS(VS_IN input)
	{
		GS_IN output = (GS_IN)0;

		output.pos = input.Position;
		output.worldPos = mul(input.Position, World);
#if MULTIVIEW
		output.InstId = input.InstId;
#endif

		return output;
	}
	
[maxvertexcount(3)]
	void GS(triangle GS_IN input[3], inout TriangleStream<PS_IN> outStream)
    {   
        PS_IN output;
        
        uint seed0 = input[0].pos.x * 8731 - input[0].pos.z * 457 + input[0].pos.y * 599;
        uint seed1 = input[0].pos.x * -8969 + input[0].pos.z * 311 - input[0].pos.y * 523;
        float seed = seed0 + seed1;
        float rnd = RandomFloat(seed);

		float4 dir = 0;
		float distorsion = 0;
		
#if PULSE
        float4 worldCenter = (input[0].worldPos + input[1].worldPos + input[2].worldPos) / 3.0;

		//float pulse = input[0].pos.y + 0.25 + cos(Time) * 0.7;
		//pulse = smoothstep(0.1,0.5, pulse);
        
        float pulse = saturate((worldCenter.y - tPosY ) * distorsionH);
        
        distorsion = 1 - lerp(InCirc(pulse), OutCirc(pulse), rnd);
		
		float4 normal = float4(GetNormal(input), 0);
#endif

#if MULTIVIEW
		const int vid = input[0].InstId % EyeCount;
		const float4x4 viewProj = MultiviewViewProj[vid];
		
		// Note which view this vertex has been sent to. Used for matrix lookup.
		// Taking the modulo of the instance ID allows geometry instancing to be used
		// along with stereo instanced drawing; in that case, two copies of each 
		// instance would be drawn, one for left and one for right.
	
		output.ViewId = vid;
#else
		float4x4 viewProj = ViewProj;
#endif

		float3 vertexColor[3] = {
			{1, 0, 0},
			{0, 1, 0},
			{0, 0, 1}
		};
		
		for (int i = 0; i < 3; i++)
		{
		
			float4 newPos = input[i].worldPos;
#if PULSE
			dir = worldCenter - input[i].worldPos;
			newPos = input[i].worldPos + normal * distorsion * Displacement + dir * distorsion;
#endif
			
	        output.pos = mul(newPos, viewProj);
	        output.extra = distorsion.xxxx;
			output.info = float4(vertexColor[i], rnd);
	        outStream.Append(output);
		}
	}

	float4 PS(PS_IN input) : SV_Target
	{	
		float minBary = min(input.info.x, min(input.info.y, input.info.z));
		minBary = smoothstep(EdgeWidth, EdgeWidth + EdgeSmooth, minBary);
		
		// Transition Color
		float3 fillcolor = lerp(FillColor0, FillColor1, input.info.w);
		float3 color = lerp(EdgeColor, fillcolor, minBary);
		float alpha = 1;
		
#if PULSE
		alpha = 1 - input.extra;
		color *= alpha;
#endif
		
		return float4(color, alpha);
	}

[End_Pass]