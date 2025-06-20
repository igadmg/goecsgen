<?go
package goecsgen

import (
	"fmt"
	"io"
	"maps"
	"slices"
	"strings"

	"deedles.dev/xiter"
	"github.com/igadmg/gogen/core"
)

func (g *GeneratorEcs) generate(wr io.Writer) {
?>
// autogenerated code
package <?= g.Pkg.Name ?>

import (
	"iter"
	"slices"

	ecs "github.com/igadmg/goecs/ecs"
	"github.com/igadmg/goex/slicesex"
	"github.com/igadmg/gamemath/vector2"
<?
	for _, p := range g.Pkg.ImportedPkgs {
?>
	<?= p.Name ?> "<?= p.Pkg.PkgPath ?>"
<?
	}
?>
)

//type EcsWorld struct {
//
//}

func RegisterWorld() {
<?
	for _, p := range g.Pkg.ImportedPkgs {
?>
	<?= p.Name ?>.Register()
<?
	}
?>
	_Entity_constraints(false)
	_Query_constraints(false)
}

func Register() {
	_Entity_constraints(false)
	_Query_constraints(false)
}

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
//// Systems for <?= len(g.systems) ?> types
///
<?
	for _, t := range g.systems {
		if t.GetPackage() != g.Pkg {
			continue
		}

		g.generateSystem(wr, t)
	}
?>

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
//// Entities num <?= len(g.entities) ?>
///

func _Entity_constraints(v bool) bool {
	if !v {
		return true
	}

<?
	for e := range maps.Values(g.entities) {
		if e.GetPackage() != g.Pkg {
			continue
		}

?>
	_<?= e.Name ?>_constraints()
<?
	}
?>

	return true
}

<?
	for i, e := range xiter.Enumerate(maps.Values(g.entities)) {
		if e.GetPackage() != g.Pkg {
			continue
		}

?>

//////////
// <?= e.Name ?>
<?
		g.generateArchetype(wr, i+1, e)

		qt := NewType(g.Pkg)
		qt.Name= e.Name + "Query"
		qt.Tag, _ = core.MakeTag("query: {" + e.QueryTags + "}")
		qt.Fields = e.Fields
		g.queries[qt.Name] = qt
		g.EntitesByQueries[qt] = append(g.EntitesByQueries[qt], e)
	}
?>

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
//// Components num <?= len(g.components) ?>
///
<?
	for _, e := range xiter.Enumerate(maps.Values(g.components)) {
		if e.GetPackage() != g.Pkg {
			continue
		}

		g.generateComponent(wr, e)
?>
//////////
// <?= e.Name ?>
<?
	}

	entitesByQueries := slices.Collect(g.QueriesSeq())
?>

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
//// Queries num <?= len(entitesByQueries) ?>
///

func _Query_constraints(v bool) bool {
	if v {
<?
	for _, q := range entitesByQueries {
		if q.Query.Package != g.Pkg {
			continue
		}

		name := strings.ReplaceAll(g.LocalTypeName(q.Query), ".", "_")
?>
		_<?= name ?>_constraints()
<?
	}
?>
	}
<?
	ai := slices.IndexFunc(entitesByQueries, func(a QueriesSeqItem) bool { return a.Query.Name == "ColonyScreenLayoutQuery" })
	_ = ai

	for _, q := range entitesByQueries {
		if !q.AnyLocal {
			continue
		}

		name := strings.ReplaceAll(g.LocalTypeName(q.Query), ".", "_")
?>
	_<?= name ?>_register()
<?
		if qt, ok := q.Query.Tag.GetObject(Tag_Query); ok && qt.HasField(Tag_Static) {
?>
	_<?= name ?>Static_register()
<?
		}
	}
?>

	return true
}
<?
	for _, q := range entitesByQueries {
		if q.Query.Package == g.Pkg {
			local_name := g.LocalTypeName(q.Query)
			type_name := strings.ReplaceAll(local_name, ".", "_")

?>

func _<?= type_name ?>_constraints() {
	var _ ecs.Id = <?= local_name ?>{}.Id
}

func (e <?= type_name ?>) Get() <?= type_name ?> {
	r, _ := <?= type_name ?>Type.Get(e.Id)
	return r
}
<?
		} else if !q.AnyLocal {
			continue
		}

?>

//////////
// <?= g.LocalTypeName(q.Query) ?>
<?
		g.generateQuery(wr, q)
	}
?>

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
//// Functions for <?= len(g.Types) ?> types
///

<?
	for _, t := range g.Types {
		if t.GetPackage() != g.Pkg {
			continue
		}

		g.generateFunctions(wr, t)
	}
?>

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
//// Debug
///

<?
	g.generateDebug(wr)
?>

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
//// Init
///

func init() {
<?
	entities := slices.Collect(maps.Values(g.entities))
?>

	rts := ecs.RequestRegisterTypes(<?= len(entities) + 1  ?>)
	_ = rts
<?
	for _, e := range entities {
		if e.GetPackage() != g.Pkg {
			continue
		}
?>
	rts[S_<?= e.Name ?>.TypeId()] = &S_<?= e.Name ?>
<?
	}
?>
}
<?
}
?>