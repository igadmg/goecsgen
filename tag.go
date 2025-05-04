package goecsgen

import (
	"gopkg.in/yaml.v3"

	"github.com/igadmg/gogen/core"
)

const (
	Tag_Archetype = "archetype"
	Tag_Feature   = "feature"
	Tag_Component = "component"
	Tag_Query     = "query"
	Tag_System    = "system"

	// Archetype tags
	Tag_Grid = "grid" // if archetype is marked as grid it's storage provides grid based functionality - special storage for continuous block i.e. for grid maps

	Tag_Extends  = "extends"  // if archetype have extends flag it designates what archetypes are extended by that one
	Tag_Abstract = "abstract" // field is abstract - it does not have it's own storage but can be overrided by subarchetypes
	Tag_Virtual  = "virtual"  // field is virtual - it does have it's own storage and can be overrided by subarchetypes

	Tag_A    = "a"    // that component in exported in get and set functions
	Tag_Save = "save" // save that component in Save function

	// Query and Archetype
	Tag_Cached = "cached" // queries or archetypes marked as cached get *Cached structs generated

	// Component tags
	Tag_Reference = "reference" // fields marked as reference are not calling Prepare, Defer, Store/Restore methods but are saved
	Tag_Transient = "transient" // fields marked as transient are not Store()'d or Restore()'d nor saved to file
)

const (
	Tag_Fn_RefCall = "fn_ref_call"
)

type Tag core.Tag

func (t Tag) GetEcsTag() EcsType {
	if _, ok := t.Data[Tag_Archetype]; ok {
		return EcsArchetype
	}
	if _, ok := t.Data[Tag_Feature]; ok {
		return EcsFeature
	}
	if _, ok := t.Data[Tag_Component]; ok {
		return EcsComponent
	}
	if _, ok := t.Data[Tag_Query]; ok {
		return EcsQuery
	}
	if _, ok := t.Data[Tag_System]; ok {
		return EcsSystem
	}

	return EcsTypeInvalid
}

func (t Tag) GetEcs() (core.Tag, bool) {
	gt := func(tag string, v any) (core.Tag, bool) {
		switch vt := v.(type) {
		case yaml.Node:
			return core.Tag(t).GetObject(tag)
		case map[string]any:
			vt["."] = tag
			return core.Tag{Data: vt}, true
		}
		return core.Tag{Data: core.TagData{".": tag}}, true
	}

	if v, ok := t.Data[Tag_Archetype]; ok {
		return gt(Tag_Archetype, v)
	}
	if v, ok := t.Data[Tag_Feature]; ok {
		return gt(Tag_Feature, v)
	}
	if v, ok := t.Data[Tag_Component]; ok {
		return gt(Tag_Component, v)
	}
	if v, ok := t.Data[Tag_Query]; ok {
		return gt(Tag_Query, v)
	}
	if v, ok := t.Data[Tag_System]; ok {
		return gt(Tag_System, v)
	}

	return core.Tag{}, false
}
