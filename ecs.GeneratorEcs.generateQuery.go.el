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

func _<?= type_name ?>_register() {
	<?= local_name ?>Type.Age = age<?= type_name ?>
	<?= local_name ?>Type.Get = get<?= type_name ?>
	<?= local_name ?>Type.Do = do<?= type_name ?>
}

func age<?= type_name ?>() (age uint64) {
	age = 0
<?
	for _, e := range qsi.Archs {
		if e.GetPackage() == g.Pkg {
?>
	age += S_<?= e.Name ?>.Age()
<?
		} else if g.Pkg.Above(e.GetPackage()) {
?>
	age += <?= e.GetPackage().Name ?>.S_<?= e.Name ?>.Age()
<?
		}
	}
?>
	return
}

func get<?= type_name ?>(id ecs.Id) (<?= local_name ?>, bool) {
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
		} else if g.Pkg.Above(e.GetPackage()) {
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
			ef := e.GetFieldByName(iq.Name) // TODO: remove linkage by name consider linkage by type
			if ef != nil {
				if ef.GetType() != iq.Type {
					baseCast = "." + iq.Type.GetName()
				}
			}
?>
			<?= iq.Name ?>: &s.S_<?= iq.Name ?>[index]<?= baseCast ?>,
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

func do<?= type_name ?>() iter.Seq[<?= local_name ?>] {
	return func(yield func(<?= local_name ?>) bool) {
<?
	for _, e := range qsi.Archs {
		if e.GetPackage() == g.Pkg {
?>
	{
		s := &S_<?= e.Name ?>
<?
		} else if g.Pkg.Above(e.GetPackage()) {
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
			ef := e.GetFieldByName(iq.Name) // TODO: remove linkage by name consider linkage by type
			if ef != nil {
				if ef.GetType() != iq.Type {
					baseCast = "." + iq.Type.GetName()
				}
			}
?>
			<?= iq.Name ?>: <?= iq.Access ?>s.S_<?= iq.Name ?>[index]<?= baseCast ?>,
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

type _<?= q.Name ?>StaticType struct {
	Age func() (age uint64)
	Get func(id ecs.Id) (<?= q.Name ?>, bool)
	Do  func() iter.Seq[<?= q.Name ?>]
}

var <?= q.Name ?>StaticType _<?= q.Name ?>StaticType

func _<?= local_name ?>Static_register() {
	<?= local_name ?>StaticType.Age = age<?= local_name ?>
	<?= local_name ?>StaticType.Get = get<?= local_name ?>
	<?= local_name ?>StaticType.Do = do<?= local_name ?>Static
}

func do<?= type_name ?>Static() iter.Seq[<?= local_name ?>] {
	return func(yield func(<?= local_name ?>) bool) {
<?
	for _, e := range qsi.Archs {
		if e.GetPackage() == g.Pkg {
?>
	{
		s := &S_<?= e.Name ?>
<?
		} else if g.Pkg.Above(e.GetPackage()) {
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