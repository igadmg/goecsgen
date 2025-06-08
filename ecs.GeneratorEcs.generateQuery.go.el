<?go
package goecsgen

import (

	"fmt"
	"io"
	"strings"
)

func (g *GeneratorEcs) generateQuery(wr io.Writer, qsi QueriesSeqItem) {
	q := qsi.Query
	local_name := g.LocalTypeName(q)
	type_name := strings.ReplaceAll(local_name, ".", "_")

	g.genAs(wr, q)
?>

type _<?= type_name ?>Type struct {
}
<?

	if q.Package == g.Pkg {
?>

type <?= type_name ?>TypeI interface {
	Age() (age uint64)
	Get(id ecs.Id) (<?= type_name ?>, bool)
	Do() iter.Seq[<?= type_name ?>]
}

var <?= type_name ?>Type <?= type_name ?>TypeI = _<?= type_name ?>Type{}
<?
	}
?>

func _<?= type_name ?>_register() {
	<?= local_name ?>Type = _<?= type_name ?>Type{}
}

func (_<?= type_name ?>Type) Age() (age uint64) {
	age = 0
<?
	for _, e := range qsi.Archs {
		if e.GetPackage() == g.Pkg {
?>
	age += S_<?= e.Name ?>.Age()
<?
		} else if g.Pkg.HasImport(e.GetPackage()) {
?>
	age += <?= e.GetPackage().Name ?>.S_<?= e.Name ?>.Age()
<?
		}
	}
?>
	return
}

func (_<?= type_name ?>Type) Get(id ecs.Id) (<?= local_name ?>, bool) {
	t := id.GetType()
	index := (int)(id.GetId() - 1)
	_ = index
	_ = t

<?
	for  _, e := range qsi.Archs {
		if e.GetPackage() == g.Pkg {
	// if s := &S_PlayerEntity; s.TypeId() == t {
	// if s := &gfx.S_PlayerEntity; s.TypeId() == t {
?>
	if s := &S_<?= e.Name ?>; s.TypeId() == t {
<?
		} else if g.Pkg.HasImport(e.GetPackage()) {
?>
	if s := &<?= e.GetPackage().Name ?>.S_<?= e.Name ?>; s.TypeId() == t {
<?
		} else {
			continue
		}
?>
		return <?= local_name ?>{
			Id:      id,
<?
		for iq := range EnumFieldsSeq(q.StructComponentsSeq()) {
			if ft := iq.Type; ft != nil && ft.IsZero() {
				continue
			}

			baseCast := ""
			fieldName := iq.Name
			ef := e.GetFieldByTypeName(iq.GetType(), iq.Name)
			if ef != nil {
				if ef.GetType() != iq.Type {
					baseCast = "." + iq.Type.GetName()
				}
				fieldName = ef.GetName()
			}
?>
			<?= iq.Name ?>: &s.S_<?= fieldName ?>[index]<?= baseCast ?>,
<?
		}
?>
		}, true
	}
<?
	}
?>

	return <?= local_name ?>{}, false
}

func (_<?= type_name ?>Type) Do() iter.Seq[<?= local_name ?>] {
	return func(yield func(<?= local_name ?>) bool) {
<?
	for _, e := range qsi.Archs {
		if e.GetPackage() == g.Pkg {
?>
	{
		s := &S_<?= e.Name ?>
<?
		} else if g.Pkg.HasImport(e.GetPackage()) {
?>
	{
		s := &<?= e.GetPackage().Name ?>.S_<?= e.Name ?>
<?
		} else {
			continue
		}
?>
	for id := range s.EntityIds() {
		index := (int)(id.GetId() - 1)
		_ = index
		if !yield(<?= local_name ?>{
			Id:       id,
<?
		for iq := range EnumFieldsSeq(q.StructComponentsSeq()) {
			if ft := iq.Type; ft != nil && ft.IsZero() {
				continue
			}

			baseCast := ""
			fieldName := iq.Name
			ef := e.GetFieldByTypeName(iq.GetType(), iq.Name)
			if ef != nil {
				if ef.GetType() != iq.Type {
					baseCast = "." + iq.Type.GetName()
				}
				fieldName = ef.GetName()
			}
?>
			<?= iq.Name ?>: <?= iq.Access ?>s.S_<?= fieldName ?>[index]<?= baseCast ?>,
<?
		}
?>
		}) {
			return
		}
	}
}
<?
	}
?>
	}
}
<?

	if qt, ok := q.Tag.GetObject(Tag_Query); ok && qt.HasField(Tag_Static) {
?>

type _Static<?= type_name ?>Type struct {
}
<?
		if q.Package == g.Pkg {
?>

type Static<?= type_name ?>TypeI interface {
	Do() iter.Seq[<?= type_name ?>]
}

var Static<?= type_name ?>Type Static<?= type_name ?>TypeI = _Static<?= type_name ?>Type{}
<?
		}
?>

func _<?= local_name ?>Static_register() {
	Static<?= type_name ?>Type = _Static<?= type_name ?>Type{}
}

func (_Static<?= type_name ?>Type) Do() iter.Seq[<?= local_name ?>] {
	return func(yield func(<?= local_name ?>) bool) {
<?
	for _, e := range qsi.Archs {
		if e.GetPackage() == g.Pkg {
?>
	{
		s := &S_<?= e.Name ?>
<?
		} else if g.Pkg.HasImport(e.GetPackage()) {
?>
	{
		s := &<?= e.GetPackage().Name ?>.S_<?= e.Name ?>
<?
		} else {
			continue
		}
?>
	for id := range s.EntityIds() {
		index := (int)(id.GetId() - 1)
		_ = index
		if !yield(<?= local_name ?>{
			Id:       id,
<?
		for iq := range EnumFieldsSeq(q.StructComponentsSeq()) {
			if ft := iq.Type; ft != nil && ft.IsZero() {
				continue
			}
?>
			<?= iq.Name ?>: <?= iq.Access ?>s.S_<?= iq.Name ?>[index],
<?
			}
?>
		}) {
			return
		}
		break
	}
}
<?
		}
?>
	}
}
<?
	}


	if q.Package == g.Pkg {
		if qt, ok := q.Tag.GetObject(Tag_Query); ok && qt.HasField(Tag_Cached) {
?>

type <?= q.Name ?>Cache struct {
	Age    uint64
	Cache []<?= q.Name ?>
}

func (r *<?= q.Name ?>Cache) Query() bool {
	q_age := <?= q.Name ?>Type.Age()
	if r.Age != q_age {
		r.Age = q_age
		r.Cache = slices.Collect(<?= q.Name ?>Type.Do())

		return true
	}

	return false
}
<?
		}
	}
}
?>