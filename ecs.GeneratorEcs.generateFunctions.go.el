<?go
package goecsgen

import (
	"fmt"
	"io"

	"github.com/igadmg/gogen/core"
)

func (g *GeneratorEcs) generateFunctions(wr io.Writer, typ core.TypeI) {
	for f := range core.EnumFuncsSeq(typ.FuncsSeq()) {
		if f.Tag.IsEmpty() {
			continue
		}
		if ecsf, ok := f.Tag.GetObject("ecs"); ok {
			if refcallf, ok := ecsf.GetField(Tag_Fn_RefCall); ok {
				decltype := refcallf
				if len(decltype) == 0 {
					decltype = f.DeclType
				}

				if ft, ok := g.GetEcsType(decltype); ok && ft.GetEcsTag().GetEcsTag() == EcsArchetype {
?>

func (o <?= decltype ?>) <?= f.Name ?>_ref() func(<?= f.DeclArguments() ?>) {
	id := o.Id
<?
				} else {
?>

func (o <?= decltype ?>) <?= f.Name ?>_ref(id ecs.Id) func(<?= f.DeclArguments() ?>) {
<?
				}
?>
	return func(<?= f.DeclArguments() ?>) {
<?
				switch Tag(typ.GetTag()).GetEcsTag() {
				case EcsArchetype:
?>
		_, o := ecs.GetT[<?= g.LocalTypeName(typ) ?>](id)

<?
				case EcsQuery:
?>
		o, ok := <?= g.LocalTypeName(typ) ?>Type.Get(id)
		if !ok {
			return
		}
<?
				}
?>
		o.<?= f.Name ?>(<?= f.CallArguments() ?>)
	}
}
<?
			}
		}
	}
}
?>