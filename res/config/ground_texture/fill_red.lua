local tu = require "texutil"

function data()
return {
	detailTex = tu.makeTextureMipmapClamp("ground_texture/fill_red.tga", true, true),
	detailNrmlTex = tu.makeTextureMipmapClamp("ground_texture/tree_ground_nrml.dds", true, true, true),
	detailSize = { 4.0, 4.0 },

	priority = 20
}
end
