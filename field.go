package goecsgen

import (
	"iter"
	"slices"
	"strings"

	"github.com/igadmg/gogen/core"
)

type EcsFieldI interface {
	core.FieldI

	GetEcsType() EcsTypeI

	IsEcsRef() bool

	GetA() string
}

type Field struct {
	core.Field

	isEcsRef bool
}

func (f Field) GetEcsType() EcsTypeI {
	return f.Type.(EcsTypeI)
}

func (f Field) IsEcsRef() bool {
	return f.isEcsRef
}

func (f Field) GetA() string {
	a, _ := f.Tag.GetField("a")
	if a == "" {
		a = f.Name
		if len(a) > 0 {
			a = strings.ToUpper(a[:1]) + a[1:]
		}
	}
	return a
}

func (f *Field) Clone() any {
	c := *f
	return &c
}

func CastField(i core.FieldI) (t *Field, ok bool) {
	t, ok = i.(*Field)
	return
}

func EnumFields(x []core.FieldI) iter.Seq[*Field] {
	return EnumFieldsSeq(slices.Values(x))
}

func EnumFieldsSeq[T core.FieldI](x iter.Seq[T]) iter.Seq[*Field] {
	return func(yield func(*Field) bool) {
		for i := range x {
			t, ok := CastField(i)
			if !ok {
				continue
			}

			if !yield(t) {
				return
			}
		}
	}
}

func (f Field) IsTransient() bool {
	if f.Tag.HasField(Tag_Transient) {
		return true
	}

	if t, ok := f.Type.(EcsTypeI); ok {
		return t.IsTransient()
	}

	return false
}

func (f Field) IsReference() bool {
	return f.Tag.HasField(Tag_Reference)
}

func (f *Field) Prepare(tf core.TypeFactory) error {
	err := f.Field.Prepare(tf)
	if err != nil {
		f.isEcsRef = strings.HasPrefix(f.TypeName, "ecs.Ref[")
		if f.isEcsRef {
			coreTypeName := strings.TrimSuffix(strings.TrimPrefix(f.TypeName, "ecs.Ref["), "]")
			if !strings.ContainsAny(coreTypeName, ".") {
				coreTypeName = f.OwnerType.GetPackage().Name + "." + coreTypeName
			}
			f.Type, _ = tf.GetType(coreTypeName)
		} else {
			return err
		}
	}

	return nil
}
