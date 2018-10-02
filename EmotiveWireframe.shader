
Shader "Custom/EmotiveWireframe"
{
	Properties
	{
		_QuadColor("QuadColor", Color) = (1,1,1,0)
		[PerRendererData]_Thickness("Opacity", float) = 5.0
		[PerRendererData]_Smoothness("WireSmoothness", float) = 3.0
		[PerRendererData]_EmoteTex("Emotion Texture", 2D) = "white" {}
		[PerRendererData]_EmoteTex_ST("Emotion Texture Tiling", Vector) = (1,1,0,0)
		[PerRendererData]_ColorTex("Color Texture", 2D) = "white" {}
		[PerRendererData]_ColorTex_ST("Color Texture Tiling", Vector) = (1,1,0,0)
		[PerRendererData]_ColorXSpeed("Color Scroll X", Range(0,10)) = 2
		[PerRendererData]_ColorYSpeed("Color Scroll Y", Range(0,10)) = 3
		[PerRendererData]_ColorTint("Color Tint", Color) = (0,0,0,1)
		[PerRendererData]_DispTex("Displacement Texture", 2D) = "gray" {}
		[PerRendererData]_DispTex_ST("Displacement Texture Tiling", Vector) = (1,1,0,0)
		[PerRendererData]_Displacement("Displacement", Range(0, 1.0)) = 0.1
		[PerRendererData]_DispSpeed("Displacement Speed", float) = 5.0
		[PerRendererData]_DispXSpeed("Displacement Scroll X", Range(0,10)) = 2
		[PerRendererData]_DispYSpeed("Displacement Scroll Y", Range(0,10)) = 3
		_ChannelFactor("ChannelFactor (r,g,b)", Vector) = (1,0,0)
		_DispAvoider("Displacement Avoider Position", Vector) = (0,0,0)
		_AvoiderRadius("Avoid Radius", Range(0,200)) = 25
		_RadiusFalloff("Avoid Radius Falloff", Range(0, 100)) = 10
	}
	SubShader
	{
		Tags{ "Queue" = "Transparent+1000" "IgnoreProjector" = "True" "RenderType" = "Transparent" }
		Blend SrcAlpha OneMinusSrcAlpha

		Pass
		{
			Name "FORWARD"
			Tags
			{
			"LightMode" = "ForwardBase"
			}
			CGPROGRAM
			#define UNITY_PASS_FORWARDBASE
			#include "UnityCG.cginc"
			#pragma target 5.0
			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag

			half4 _QuadColor, _ColorTint;
			float _Thickness, _Smoothness; //TODO: implement?
			sampler2D _DispTex, _ColorTex, _EmoteTex;
			float4 _DispTex_ST, _ColorTex_ST, _EmoteTex_ST;
			float _Displacement;
			float3 _ChannelFactor;
			float _ColorXSpeed, _ColorYSpeed;
			float _DispXSpeed, _DispYSpeed;
			float _DispSpeed;
			float3 _DispAvoider;
			float _AvoiderRadius, _RadiusFalloff;

			struct VertexInput 
			{
				float4 vertex : POSITION;	  //local vertex position, used in wireframe
				float3 normal : NORMAL;		  //normal direction
				float4 tangent : TANGENT;	  //tangent direction
				float2 texcoord0 : TEXCOORD0; //uv coordinates
				float2 texcoord1 : TEXCOORD1; //lightmap uv coordinates
			};

			struct VertexOutput
			{
				//used for wireframe
				float4  pos : SV_POSITION; 
				//used for points
				half psize : PSIZE;
				//used for vertex displacement
				float2  uv0 : TEXCOORD0;
				float2  uv1 : TEXCOORD1;
				float3 normalDir : TEXCOORD3; 
				float3 posWorld : TEXCOORD4; //also normal direction
			};

			struct GeometryIO
			{
				float4  pos : SV_POSITION;
				float2  uv0 : TEXCOORD0;
				float3 dist : TEXCOORD5; //was originally TEXCOORD1 but conflicted with the frag function
			};

			//displacement part of the shader
			VertexOutput vert(VertexInput v)
			{
				VertexOutput OUT;
				//for vertex displacement
				OUT.uv0 = TRANSFORM_TEX(v.texcoord0, _ColorTex);
				OUT.uv1 = v.texcoord1;
				OUT.normalDir = UnityObjectToWorldNormal(v.normal);
				//applying movement
				fixed displacementXScroll = _DispXSpeed * _Time * _DispSpeed * _DispTex_ST.x;
				fixed displacementYScroll = _DispYSpeed * _Time * _DispSpeed * _DispTex_ST.y;
				fixed2 displacementScrolledUV = TRANSFORM_TEX(OUT.uv0, _DispTex);
				displacementScrolledUV += fixed2(displacementXScroll,displacementYScroll);
				float4 dispColor = tex2Dlod(_DispTex, float4(displacementScrolledUV, 0, 0));
				float d = (dispColor.r * _ChannelFactor.r + dispColor.g *_ChannelFactor.g + dispColor.b * _ChannelFactor.b);
				//check if at position of avoider + radius and not apply displacement
				float3 wpos = mul(_Object2World, v.vertex).xyz;
				//check should be 1 if within the radius, 0 if not 
				float distance = sqrt(pow((wpos.x - _DispAvoider.x),2) + pow((wpos.y - _DispAvoider.y),2) + pow((wpos.z - _DispAvoider.z),2));
				float check = step(distance, _AvoiderRadius);
				//for checking emotive map
				float4 emotiveData = tex2Dlod(_EmoteTex, float4(OUT.uv0, 0, 0));
				float smoothness = sin(_Displacement + _Smoothness);
				if (check < 1) { //not within the radius
					v.vertex.xyz += v.normal * d * _Displacement * emotiveData.r;
				}
				else
				{ //within radius
					float falloff = _AvoiderRadius - _RadiusFalloff;
					if (distance >= falloff) {
						//falloff calculations
						float diff = distance - falloff;
						float falloffPerc = diff / _RadiusFalloff;
						v.vertex.xyz += v.normal * d * _Displacement * emotiveData.r * falloffPerc;
					}
				}
				
				//for wireframe as well
				OUT.pos = mul(UNITY_MATRIX_MVP, v.vertex);
				OUT.posWorld = mul(_Object2World, v.vertex);
				return OUT;
			}

			[maxvertexcount(3)]
			void geom(triangle VertexOutput IN[3], inout TriangleStream<GeometryIO> triStream)
			{
				float2 WIN_SCALE = float2(_ScreenParams.x / 2.0, _ScreenParams.y / 2.0);

				//frag position
				float2 p0 = WIN_SCALE * IN[0].pos.xy / IN[0].pos.w;
				float2 p1 = WIN_SCALE * IN[1].pos.xy / IN[1].pos.w;
				float2 p2 = WIN_SCALE * IN[2].pos.xy / IN[2].pos.w;

				//barycentric position
				float2 v0 = p2 - p1;
				float2 v1 = p2 - p0;
				float2 v2 = p1 - p0;
				//triangles area
				float area = abs(v1.x*v2.y - v1.y * v2.x);

				GeometryIO OUT;
				OUT.pos = IN[0].pos;
				OUT.uv0 = IN[0].uv0;
				OUT.dist = float3(area / length(v0),0,0);
				triStream.Append(OUT);

				OUT.pos = IN[1].pos;
				OUT.uv0 = IN[1].uv0;
				OUT.dist = float3(0,area / length(v1),0);
				triStream.Append(OUT);

				OUT.pos = IN[2].pos;
				OUT.uv0 = IN[2].uv0;
				OUT.dist = float3(0,0,area / length(v2));
				triStream.Append(OUT);

			}

			//wireframe section of the shader
			half4 frag(GeometryIO GIN, VertexOutput VIN) : COLOR
			{				
				//apply scrolling effect with colours
				fixed textureXScroll = _ColorXSpeed * _Time * _ColorTex_ST.x;
				fixed textureYScroll = _ColorYSpeed * _Time * _ColorTex_ST.y;
				fixed2 scrolledTextureUV = VIN.uv0;
				scrolledTextureUV += fixed2(textureXScroll, textureYScroll);
				half4 scrolledColor = tex2D(_ColorTex, scrolledTextureUV);
				if (_ColorTint.a >= 0.2f) { half4 scrolledColor = scrolledColor * _ColorTint; }
				//distance of frag from triangles center
				float e = min(GIN.dist.x, min(GIN.dist.y, GIN.dist.z));
				//fade based on dist from center
				float I = exp2(-4.0*e*e) - _Thickness;
				half4 wireFrame = lerp(_QuadColor, scrolledColor, I);
				//if you need to tint the wireframe a particular color it needs to have a high enough alpha
				if (_ColorTint.a >= 0.2f) { wireFrame = lerp(_QuadColor, _ColorTint, I); }
				
				return wireFrame;
			}
			ENDCG

		}
	}
	Fallback "Diffuse"
}