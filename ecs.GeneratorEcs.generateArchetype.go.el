<?go
package goecsgen

import (
	"fmt"
	"io"
)

func (g *GeneratorEcs) generateArchetype(wr io.Writer, id int, e *Type) {
	g.genAs(wr, e)

	eName := g.LocalTypeName(e)
?>

func _<?= eName ?>_constraints() {
	var _ ecs.Id = <?= eName ?>{}.Id
}

type storage_<?= eName ?> struct {
	ecs.BaseStorage

<?
	for c := range EnumFieldsSeq(e.StructComponentsSeq()) {
?>
	S_<?= c.Name ?> []<?= g.LocalTypeName(c.GetType()) ?>
<?
	}
?>
}

var S_<?= eName ?> = storage_<?= eName ?>{
	BaseStorage: ecs.MakeBaseStorage(<?= id  ?>),
}

func Match<?= eName ?>(id ecs.Id) (ecs.Ref[<?= eName ?>], bool) {
	if id.GetType() == S_<?= eName ?>.TypeId() {
		ref := ecs.Ref[<?= eName ?>]{Id: id}
		_ = ref.Get()

		return ref, true
	}
<?
	for s := range EnumTypes(e.Subclasses) {
?>
	if id.GetType() == S_<?= s.Name ?>.TypeId() {
		ref := ecs.Ref[<?= eName ?>]{Id: id}
		_ = ref.Get()

		return ref, true
	}
<?
	}
?>

	return ecs.Ref[<?= eName ?>]{}, false
}

func (e <?= eName ?>) Ref() ecs.Ref[<?= eName ?>] {
	return ecs.Ref[<?= eName ?>] {
		Id: e.Id,
		Age: S_<?= eName ?>.Age(),
		Ptr: e,
	}
}

func (e <?= eName ?>) Get() <?= eName ?> {
	ref := ecs.Ref[<?= eName ?>] {
		Id: e.Id,
	}
	return ref.Get()
}

func (e <?= eName ?>) Allocate() ecs.Ref[<?= eName ?>] {
	s := &S_<?= eName ?>
	age, id := s.BaseStorage.AllocateId()
	index := (int)(id.GetId() - 1)
	_ = index

<?
	for c := range EnumFieldsSeq(e.StructComponentsSeq()) {
?>
	s.S_<?= c.Name ?> = slicesex.Reserve(s.S_<?= c.Name ?>, index+1)
<?
	}
?>

	ref := ecs.Ref[<?= eName ?>]{
		Age: age - 1,
		Id:  id,
	}
	_ = ref.Get()

<?

	for c := range EnumFieldsSeq(e.StructComponentsSeq()) {
		if ct, ok := CastType(c.Type); ok {
			if ct.IsZero() {
				continue
			}
			if ct.IsTransient() {
				continue
			}

?>
	if e.<?= c.Name ?> != nil {
		*ref.Ptr.<?= c.Name ?> = *e.<?= c.Name ?>
	}
<?
		}
 	}
?>

	return ref
}

func (e <?= eName ?>) Free() {
	Free<?= eName ?>(e.Id)
}

<?
	g.fnLoad(wr, e)
	if !e.IsTransient() {
		g.fnStore(wr, e)
		g.fnRestore(wr, e)
	}
?>

func Allocate<?= eName ?>() (ref ecs.Ref[<?= eName ?>], entity <?= eName ?>) {
	var e <?= eName ?>
	ref = e.Allocate()
	return ref, ref.Ptr
}

func Free<?= eName ?>(id ecs.Id) {
	s := &S_<?= eName ?>
	index := (int)(id.GetId() - 1)
	_ = index

<?
	for c := range EnumFieldsSeq(e.StructComponentsSeq()) {
?>
	s.S_<?= c.Name ?>[index] = <?= g.LocalTypeName(c.GetType()) ?>{}
<?
 	}
?>

	s.Free(id)
}

func Update<?= eName ?>Id(id ecs.Id) {
	tid := id.GetType()
	if s := S_<?= eName ?>; s.TypeId() == tid {
		index := (int)(id.GetId() - 1)

		S_<?= eName ?>.Ids[index] = id
	}
}
<?
	if _, ok := g.queries[eName+"Query"]; !ok {
?>

// Auto-generated query for <?= e.Name ?> entity
type <?= eName ?>Query struct {
	_ ecs.MetaTag `ecs:"query: {<?= e.QueryTags ?>}"`

	Id ecs.Id
<?
	for c := range EnumFieldsSeq(e.QueryComponentsSeq()) {

?>
	<?= c.Name ?> *<?= g.LocalTypeName(c.GetType()) ?>
<?
	}
?>
}
<?
	}
}

func (g *GeneratorEcs) genFieldEcsCall(wr io.Writer, f *Field, call string) {
	if f.IsArray() {
		if f.isEcsRef {
?>
	for i := range e.<?= f.Name ?> {
		<?= call ?>(&e.<?= f.Name ?>[i])
}
<?
		} else if f.Type.CanCall(call) {
?>
	for i := range e.<?= f.Name ?> {
		e.<?= f.Name ?>[i].<?= call ?>()
}
<?
		}
	} else {
		if f.isEcsRef {
?>
	<?= call ?>(&e.<?= f.Name ?>)
<?
		} else if f.Type.CanCall(call) {
?>
	e.<?= f.Name ?>.<?= call ?>()
<?
		}
	}
}

func (g *GeneratorEcs) fnLoad(wr io.Writer, e *Type) {
	if e.HasFunction("Load") {
		return
	}

	eName := g.LocalTypeName(e)

?>
func (e <?= eName ?>) Load(age uint64, id ecs.Id) (uint64, <?= eName ?>) {
	index := (int)(id.GetId() - 1)
	tid := id.GetType()
	_ = index

<?
 	for _, s := range e.Subclasses {
		switch sc := s.(type) {
		case *Type:
?>
	if s := &S_<?= sc.Name ?>; s.TypeId() == tid {
		if age != s.Age() {
			e.Id = id
<?
			for field := range EnumFields(e.Fields) {
				if ft := field.Type; ft != nil && ft.IsZero() {
					continue
				}

				if field.Tag.HasField(Tag_Virtual) || field.Tag.HasField(Tag_Abstract) {
?>
			e.<?= field.Name ?> = &s.S_<?= field.Name ?>[index].<?= field.GetTypeName() ?>
<?
				} else {
?>
			e.<?= field.Name ?> = &s.S_<?= field.Name ?>[index]
<?
				}
			}
			for c := range e.ComponentOverridesSeq() {
?>
			e.<?= c.Base.Name ?>.<?= c.Field.Name ?> = &e.<?= c.Field.Name ?>.<?= c.Field.GetTypeName() ?>
<?
			}
?>
			age = s.Age()
		}

		return age, e
	}
<?
		}
	}
?>
	if s := S_<?= eName ?>; s.TypeId() == tid {
		if age != s.Age() {
			e.Id = id
<?
	for c := range EnumFieldsSeq(e.StructComponentsSeq()) {
		if ft := c.Type; ft != nil && ft.IsZero() {
			continue
		}
?>
			e.<?= c.Name ?> = &s.S_<?= c.Name ?>[index]
<?
 	}
	for c := range e.ComponentOverridesSeq() {
?>
			e.<?= c.Base.Name ?>.<?= c.Field.Name ?> = &e.<?= c.Field.Name ?>.<?= c.Field.GetTypeName() ?>
<?
	}
?>
			age = s.Age()
		}

		return age, e
	}

	panic("Wrong type requested.")
}
<?
}

func (g *GeneratorEcs) fnStore(wr io.Writer, typ *Type) {
	if !typ.NeedStore() {
		return
	}

	typName := g.LocalTypeName(typ)

?>

func (e *<?= typName ?>) Store() {
<?
	for field := range EnumFieldsSeq(typ.StoreComponentsSeq()) {
		if ft := field.Type; ft != nil && ft.IsZero() {
			continue
		}

		if field.IsArray() {
		} else {
			if field.isEcsRef {
			} else {
?>
	c_<?= field.Name ?> := *e.<?= field.Name ?>
	e.<?= field.Name ?> = &c_<?= field.Name ?>
<?
			}
		}

		g.genFieldEcsCall(wr, field, "Store")
	}
?>
	Update<?= typName ?>Id(e.Id.Store())
}
<?
}

func (g *GeneratorEcs) fnRestore(wr io.Writer, typ *Type) {
	if !typ.NeedRestore() {
		return
	}

	typName := g.LocalTypeName(typ)

?>

func (e *<?= typName ?>) Restore() {
<?
	for field := range EnumFieldsSeq(typ.StoreComponentsSeq()) {
		if field.IsArray() {
		} else {
		}

		g.genFieldEcsCall(wr, field, "Restore")
	}

	if typ.CanCall("Construct") {
?>
		e.Construct()
<?
	}

?>
	Update<?= typName ?>Id(e.Id.Restore())
}
<?
}
?>