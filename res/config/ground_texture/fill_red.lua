local tu = require "texutil"

function data()
return {
	detailTex = tu.makeTextureMipmapRepeat("ground_texture/fill_red.tga", true, true),
	detailNrmlTex = tu.makeTextureMipmapRepeat("ground_texture/tree_ground_nrml.dds", true, true, true),
	detailSize = { 1.0, 1.0 },
	priority = 22
}
end
