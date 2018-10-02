using UnityEngine;
using System.Collections;
using System.Collections.Generic;
/// <summary>
/// controls the EmotiveWireframe shader on the same object
/// note: materialPropertyBlock breaks dynamic batching of renderers
/// </summary>
public class EmotiveShaderController : MonoBehaviour {

	//some of my meshes were skinned renderers, some were mesh renderers
    private MeshRenderer emotiveRenderer;
    private SkinnedMeshRenderer emotiveRendererSkinned;
    private MaterialPropertyBlock emotivePropertyBlock;
    private float textureWidth;
    private float textureHeight;

    public ShaderVariables defaultShaderVariables;
	
	public bool matchTerrain;
	
	void Start ()
    {
        emotivePropertyBlock = new MaterialPropertyBlock();
        if (GetComponent<MeshRenderer>() != null) { emotiveRenderer = GetComponent<MeshRenderer>(); emotiveRenderer.GetPropertyBlock(emotivePropertyBlock); }
        else if (GetComponent<SkinnedMeshRenderer>() != null) { emotiveRendererSkinned = GetComponent<SkinnedMeshRenderer>(); emotiveRendererSkinned.GetPropertyBlock(emotivePropertyBlock); }

        textureHeight = defaultShaderVariables.colorTexture.height;
        textureWidth = defaultShaderVariables.colorTexture.width;
        UpdateShader(defaultShaderVariables);
	}

	//checks if should match the terrain colour in its position on the Y axis
    public void AdjustColor()
    {
        if (matchTerrain)
        {
            Bounds meshBounds = new Bounds();
            if (emotiveRenderer != null) { meshBounds = emotiveRenderer.bounds; }
            else if(emotiveRendererSkinned != null) { meshBounds = emotiveRendererSkinned.bounds; }
            
            if(meshBounds.center == Vector3.zero) { Debug.Log(transform.name + " mesh bounds not set, check renderer"); }
            Vector3 worldPos = meshBounds.center;
            RaycastHit hit;
            Vector2 pixelCoord = Vector2.zero;
            //raycast: need mesh renderer on the object, it cannot be convex
            if (Physics.Raycast(worldPos, Vector3.down, out hit))
            {
                pixelCoord = hit.textureCoord;
                pixelCoord.x *= textureHeight;
                pixelCoord.y *= textureWidth;
            }
            defaultShaderVariables.tint = defaultShaderVariables.colorTexture.GetPixel((int)pixelCoord.x, (int)pixelCoord.y);
        }
        UpdateShader(defaultShaderVariables);
    }
	
    public void UpdateVariables(ShaderVariables newVariables)
    {
        UpdateShader(newVariables);
    }

    private void UpdateShader(ShaderVariables variables)
    {
        if(emotiveRenderer != null) { emotiveRenderer.GetPropertyBlock(emotivePropertyBlock); }
        else if (emotiveRendererSkinned != null) { emotiveRendererSkinned.GetPropertyBlock(emotivePropertyBlock); }
        emotivePropertyBlock.SetFloat("_Smoothness", variables.smoothness);
        if(variables.emotionTexure != null) { emotivePropertyBlock.SetTexture("_EmoteTex", variables.emotionTexure); }
        if(variables.colorTexture != null) { emotivePropertyBlock.SetTexture("_ColorTex", variables.colorTexture); }
        emotivePropertyBlock.SetColor("_ColorTint", variables.tint);
        emotivePropertyBlock.SetFloat("_ColorXSpeed", variables.colorXSpeed);
        emotivePropertyBlock.SetFloat("_ColorYSpeed", variables.colorZSpeed);
        if(variables.displTexture != null) { emotivePropertyBlock.SetTexture("_DispTex", variables.displTexture); }
        emotivePropertyBlock.SetFloat("_Displacement", variables.displacement);
        emotivePropertyBlock.SetFloat("_DispSpeed", variables.displYSpeed);
        emotivePropertyBlock.SetFloat("_DispXSpeed", variables.displXSpeed);
        emotivePropertyBlock.SetFloat("_DispYSpeed", variables.displZSpeed);
        if (emotiveRenderer != null) { emotiveRenderer.SetPropertyBlock(emotivePropertyBlock); }
        else if (emotiveRendererSkinned != null) { emotiveRendererSkinned.SetPropertyBlock(emotivePropertyBlock); }    
    }
}
