<?go
package goecsgen

import (
	"fmt"
	"io"
)

func (g *GeneratorEcs) genAs(wr io.Writer, t *Type) {
	//if !t.NeedAs() {
	//	return
	//}

	for f := range EnumFields(t.Fields) {
		if fet, ok := f.GetType().(EcsTypeI); ok {
			for af := range fet.AsComponentsSeq() {
				if af.IsEcsRef() {
					if af.IsArray() {
						if !t.HasFunction(af.GetA()) {
?>

func (e <?= t.Name ?>) <?= af.GetA() ?>(i int) <?= g.LocalTypeName(af.GetType()) ?> {
	return e.<?= f.GetName() ?>.<?= af.GetName() ?>[i].Get()
}
<?
						}

						if !t.HasFunction(af.GetA() + "Ref") {
?>

func (e <?= t.Name ?>) <?= af.GetA() ?>Ref(i int) ecs.Ref[<?= g.LocalTypeName(af.GetType()) ?>] {
	return e.<?= f.GetName() ?>.<?= af.GetName() ?>[i]
}
<?
						}

						if !t.HasFunction("Set" + af.GetA()) {
?>

func (e <?= t.Name ?>) Set<?= af.GetA() ?>(i int, v <?= af.GetTypeName() ?>) {
	e.<?= f.GetName() ?>.<?= af.GetName() ?>[i] = v
}
<?
						}
					} else {
						if !t.HasFunction(af.GetA()) {
?>

func (e <?= t.Name ?>) <?= af.GetA() ?>() <?= g.LocalTypeName(af.GetType()) ?> {
	return e.<?= f.GetName() ?>.<?= af.GetName() ?>.Get()
}
<?
						}

						if !t.HasFunction(af.GetA() + "Ref") {
?>

func (e <?= t.Name ?>) <?= af.GetA() ?>Ref() ecs.Ref[<?= g.LocalTypeName(af.GetType()) ?>] {
	return e.<?= f.GetName() ?>.<?= af.GetName() ?>
}
<?
						}

						if !t.HasFunction("Set" + af.GetA()) {
?>

func (e <?= t.Name ?>) Set<?= af.GetA() ?>(v <?= af.GetTypeName() ?>) {
	e.<?= f.GetName() ?>.<?= af.GetName() ?> = v
}
<?
						}

						if !t.HasFunction("Reset" + af.GetA()) {
?>

func (e <?= t.Name ?>) Reset<?= af.GetA() ?>() {
	e.<?= f.GetName() ?>.<?= af.GetName() ?>.Id = ecs.InvalidId
}
<?
						}
					}
				} else {
					if !t.HasFunction(af.GetA()) {
?>

func (e <?= t.Name ?>) <?= af.GetA() ?>() <?= af.GetTypeName() ?> {
	return e.<?= f.GetName() ?>.<?= af.GetName() ?>
}
<?
					}

					if !t.HasFunction("Set" + af.GetA()) {
?>

func (e <?= t.Name ?>) Set<?= af.GetA() ?>(v <?= af.GetTypeName() ?>) {
	e.<?= f.GetName() ?>.<?= af.GetName() ?> = v
}
<?
					}
				}
			}
		}
	}
}
?>