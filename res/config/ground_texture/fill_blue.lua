local tu = require "texutil"

function data()
return {
	detailTex = tu.makeTextureMipmapRepeat("ground_texture/fill_blue.tga", true, true),
	detailNrmlTex = tu.makeTextureMipmapRepeat("ground_texture/tree_ground_nrml.dds", true, true, true),
	detailSize = { 3.0, 3.0 },
	priority = 21
}
end
