package goecsgen

import (
	"iter"
	"slices"
	"strings"

	"deedles.dev/xiter"
	"github.com/hymkor/go-lazy"
	"github.com/igadmg/goex"
	"github.com/igadmg/gogen/core"
)

type EcsType int

const (
	EcsTypeInvalid EcsType = iota
	EcsArchetype
	EcsFeature
	EcsComponent
	EcsQuery
	EcsSystem
)

type EcsTypeI interface {
	core.TypeI

	GetEcsTag() Tag

	IsTransient() bool

	//
	NeedStore() bool
	HasStore() bool
	NeedRestore() bool
	HasRestore() bool
	NeedSave() bool
	HasSave() bool

	NeedAs() bool

	StructComponentsSeq() iter.Seq[EcsFieldI]
	QueryComponentsSeq() iter.Seq[EcsFieldI]
	ComponentsSeq() iter.Seq[EcsFieldI]
	AsComponentsSeq() iter.Seq[EcsFieldI]
	SaveComponentsSeq() iter.Seq[EcsFieldI]

	ReversedStructComponentsSeq() iter.Seq[EcsFieldI]
	ReversedQueryComponentsSeq() iter.Seq[EcsFieldI]
}

type Type struct {
	core.Type `yaml:",inline"`

	EType     EcsType `yaml:""`
	QueryTags string  `yaml:""`

	Components       *lazy.Of[[]EcsFieldI]
	StructComponents *lazy.Of[[]EcsFieldI]
	QueryComponents  *lazy.Of[[]EcsFieldI]
	needStore        *lazy.Of[bool]
	needSave         *lazy.Of[bool]
	needAs           *lazy.Of[bool]
	HaveBaseEntity   bool `yaml:""`
}

var _ EcsTypeI = (*Type)(nil)
var _ core.TypeBuilder = (*Type)(nil)

func (t Type) GetEcsTag() Tag {
	return Tag(t.Tag)
}

func (t Type) CanCall(name string) bool {
	switch name {
	case "Store":
		return t.HasStore()
	case "Restore":
		return t.HasRestore()
	}

	return t.Type.CanCall(name)
}

func (t Type) NeedStore() bool {
	return !t.IsTransient() && !t.HasFunction("Store") &&
		t.needStore.Value()
}

func (t Type) HasStore() bool {
	return !t.IsTransient() && (t.HasFunction("Store") || t.NeedStore())
}

func (t Type) NeedRestore() bool {
	return !t.IsTransient() && !t.HasFunction("Restore") &&
		t.needStore.Value()
}

func (t Type) HasRestore() bool {
	return !t.IsTransient() && (t.HasFunction("Restore") || t.NeedRestore())
}

func (t Type) NeedSave() bool {
	return t.needSave.Value()
}

func (t Type) HasSave() bool {
	return false
}

func (t Type) NeedAs() bool {
	return t.needAs.Value()
}

func MakeType(pkg *core.Package) Type {
	return Type{
		Type: core.MakeType(pkg),
	}
}

func NewType(pkg *core.Package) *Type {
	t := MakeType(pkg)
	return t.New()
}

func (t *Type) New() *Type {
	t.Type.New()

	t.Components = lazy.New(func() []EcsFieldI {
		return slices.Collect(
			func(yield func(EcsFieldI) bool) {
				for _, field := range t.Fields {
					if field.GetTag().HasField(Tag_Abstract) {
						continue
					}

					if !yield(field.(EcsFieldI)) {
						return
					}
				}
			},
		)
	})
	t.StructComponents = lazy.New(func() []EcsFieldI {
		r := slices.Collect(t.ReversedStructComponentsSeq())
		slices.Reverse(r)
		return r
	})
	t.QueryComponents = lazy.New(func() []EcsFieldI {
		r := slices.Collect(t.ReversedQueryComponentsSeq())
		slices.Reverse(r)
		return r
	})

	t.needStore = lazy.New(func() bool {
		return !xiter.IsEmpty(t.StoreComponentsSeq())
	})

	t.needSave = lazy.New(func() bool {
		return !xiter.IsEmpty(xiter.Filter(
			slices.Values(t.Fields),
			func(f core.FieldI) bool {
				return f.GetTypeName() == "SaveTag"
			},
		))
	})

	t.needAs = lazy.New(func() bool {
		return !xiter.IsEmpty(t.AsComponentsSeq())
	})

	return t
}

func CastType(i core.TypeI) (t *Type, ok bool) {
	t, ok = i.(*Type)
	return
}

func EnumTypes(x []core.TypeI) iter.Seq[*Type] {
	return func(yield func(*Type) bool) {
		for _, i := range x {
			t, ok := CastType(i)
			if !ok {
				continue
			}

			if !yield(t) {
				return
			}
		}
	}
}

func (t Type) CanHaveIdField() bool {
	return t.EType == EcsComponent
}

func (t Type) IsTransient() bool {
	if ecsn, ok := Tag(t.Tag).GetEcs(); ok {
		return ecsn.HasField(Tag_Transient)
	}

	return !t.HasFunction("Store")
}

func (t Type) ReversedStructComponentsSeq() iter.Seq[EcsFieldI] {
	return func(yield func(EcsFieldI) bool) {
		lcm := map[string]EcsFieldI{}

		fields := slices.Collect(t.ComponentsSeq())
		slices.Reverse(fields)
		for _, field := range fields {
			if !t.CanHaveIdField() && field.GetName() == "Id" {
				continue
			}
			if !yield(field) {
				return
			}
			lcm[field.GetName()] = field
		}

		bases := slices.Clone(t.BaseFields)
		slices.Reverse(bases)
		for _, base := range bases {
			if bt, ok := base.GetType().(EcsTypeI); ok {
				for field := range bt.ReversedStructComponentsSeq() {

					func() {
						fn := field.GetName()
						mf, ok := field.(core.TokenM)
						if !ok {
							return
						}

						if pt, ok := base.GetTag().GetObject("prepare"); ok {
							if prepf, ok := pt.GetField(fn); ok {
								// here we clone base fields and override "prepare"
								if field, ok = goex.Clone[EcsFieldI](mf); ok {
									tag := field.GetTag()
									mf, _ = field.(core.TokenM)

									tag.SetField("prepare", prepf)
									mf.SetTag(tag)
								}
							}
						}
					}()

					_, ok := lcm[field.GetName()]
					lcm[field.GetName()] = field
					if !ok && !yield(field) {
						return
					}
				}
			}
		}
	}
}

func (t Type) ReversedQueryComponentsSeq() iter.Seq[EcsFieldI] {
	return func(yield func(EcsFieldI) bool) {
		lcm := map[string]EcsFieldI{}

		fields := []EcsFieldI{}
		for _, field := range t.Fields {
			fields = append(fields, field.(EcsFieldI))
		}
		slices.Reverse(fields)

		for _, field := range fields {
			if !t.CanHaveIdField() && field.GetName() == "Id" {
				continue
			}
			if !yield(field) {
				return
			}
			lcm[field.GetName()] = field
		}

		bases := slices.Clone(t.BaseFields)
		slices.Reverse(bases)
		for _, base := range bases {
			if bt, ok := base.GetType().(EcsTypeI); ok {
				for field := range bt.ReversedQueryComponentsSeq() {

					func() {
						fn := field.GetName()
						mf, ok := field.(core.TokenM)
						if !ok {
							return
						}

						if pt, ok := base.GetTag().GetObject("prepare"); ok {
							if prepf, ok := pt.GetField(fn); ok {
								// here we clone base fields and override "prepare"
								if field, ok = goex.Clone[EcsFieldI](mf); ok {
									tag := field.GetTag()
									mf, _ = field.(core.TokenM)

									tag.SetField("prepare", prepf)
									mf.SetTag(tag)
								}
							}
						}
					}()

					_, ok := lcm[field.GetName()]
					lcm[field.GetName()] = field
					if !ok && !yield(field) {
						return
					}
				}
			}
		}
	}
}

func (t Type) StructComponentsSeq() iter.Seq[EcsFieldI] {
	return slices.Values(t.StructComponents.Value())
}

func (t Type) QueryComponentsSeq() iter.Seq[EcsFieldI] {
	return slices.Values(t.QueryComponents.Value())
}

func (t Type) ComponentsSeq() iter.Seq[EcsFieldI] {
	return slices.Values(t.Components.Value())
}

type ComponentOverride struct {
	Base  *Type
	Field *Field
}

func (t Type) ComponentOverridesSeq() iter.Seq[ComponentOverride] {
	return func(yield func(ComponentOverride) bool) {
		for base := range EnumFields(t.BaseFields) {
			be, ok := CastType(base.Type)
			if !ok {
				continue
			}

			for field := range EnumFields(be.Fields) {
				if field.Tag.HasField(Tag_Virtual) || field.Tag.HasField(Tag_Abstract) {
					if !yield(ComponentOverride{
						Base:  be,
						Field: field,
					}) {
						return
					}
				}
			}
		}
	}
}

func (t *Type) StoreComponentsSeq() iter.Seq[EcsFieldI] {
	return func(yield func(EcsFieldI) bool) {
		for field := range EnumFieldsSeq(t.StructComponentsSeq()) {
			if field.Type == nil {
				continue
			}

			if field.IsTransient() {
				continue
			}

			if field.IsReference() {
				continue
			}

			if !field.GetEcsType().HasStore() {
				if field.Type.GetTag().IsEmpty() {
					continue
				}

				//if gft, ok := field.Type.(GogTypeI); ok && !gft.NeedStore() {
				//	continue
				//}

				//if t.Etype != EcsArchetype  && !field.IsComponent {
				//	continue
				//}

				if !field.IsArray() {
					if !field.isEcsRef && (field.Tag.HasField(Tag_Virtual)) {
						continue
					}
				}
			}

			if !yield(field) {
				return
			}
		}
	}
}

func (t *Type) AsComponentsSeq() iter.Seq[EcsFieldI] {
	return func(yield func(EcsFieldI) bool) {
		for field := range EnumFieldsSeq(t.StructComponentsSeq()) {
			if !field.Tag.HasField(Tag_A) {
				continue
			}

			if !yield(field) {
				return
			}
		}
	}
}

func (t *Type) SaveComponentsSeq() iter.Seq[EcsFieldI] {
	return func(yield func(EcsFieldI) bool) {
		for field := range EnumFieldsSeq(t.StructComponentsSeq()) {
			if !field.Tag.HasField(Tag_Save) {
				continue
			}

			if !yield(field) {
				return
			}
		}
	}
}

func (t *Type) Prepare(tf core.TypeFactory) error {
	err := t.Type.Prepare(tf)
	if err != nil {
		return err
	}

	for _, base := range t.BaseFields {
		if strings.HasPrefix(base.GetTypeName(), "ecs.Archetype") {
			t.HaveBaseEntity = true
			break
		}
	}

	t.EType = Tag(t.Tag).GetEcsTag()
	if t.EType != EcsTypeInvalid {
		if et, ok := Tag(t.Tag).GetEcs(); ok {
			if et.HasField(Tag_Cached) {
				t.QueryTags = Tag_Cached
			}

			if t.EType == EcsArchetype {
				if ef, ok := et.GetField(Tag_Extends); ok {
					if et, ok := tf.GetType(ef); ok {
						t.Extends = append(t.Extends, et)
					}
				}
			}
		}
	}

	return nil
}
