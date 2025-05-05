<?go
package goecsgen

import (
	"fmt"
	"io"
)

func (g *GeneratorEcs) generateComponent(wr io.Writer, e *Type) {
	g.genDto(wr, e)

	g.fnComponentStore(wr, e)
	g.fnComponentRestore(wr, e)

?>

func (c *<?= e.Name ?>) Pack() {
<?
	for field := range EnumFieldsSeq(e.PackedComponentsSeq()) {
		ft := field.Type
		ftpkg := g.TypeImportName(ft)
		if field.IsArray() {
?>
	for i := range c.<?= field.Name ?> {
		c.<?= field.Name ?>[i].Id = <?= ftpkg ?>Pack<?= ft.GetName() ?>(c.<?= field.Name ?>[i].Id)
	}
<?
		} else {
?>
	c.<?= field.Name ?>.Id = <?= ftpkg ?>Pack<?= ft.GetName() ?>(c.<?= field.Name ?>.Id)
<?
		}
	}
?>
}
<?
}

func (g *GeneratorEcs) fnComponentStore(wr io.Writer, typ *Type) {
	if !typ.NeedStore() {
		return
	}
?>

func (e *<?= typ.Name ?>) Store() {
<?
	for field := range EnumFieldsSeq(typ.StoreComponentsSeq()) {
		if field.isEcsRef {
			if field.IsArray() {
?>
	for i := range e.<?= field.Name ?> {
		e.<?= field.Name ?>[i].Store()
	}
<?
			} else {
?>
	e.<?= field.Name ?>.Store()
<?
			}
		}
	}
?>
}
<?
}

func (g *GeneratorEcs) fnComponentRestore(wr io.Writer, typ *Type) {
	if !typ.NeedRestore() {
		return
	}
?>

func (e *<?= typ.Name ?>) Restore() {
<?
	for field := range EnumFieldsSeq(typ.StoreComponentsSeq()) {
		if field.isEcsRef {
			if field.IsArray() {
?>
	for i := range e.<?= field.Name ?> {
		e.<?= field.Name ?>[i].Restore()
	}
<?
			} else {
?>
	e.<?= field.Name ?>.Restore()
<?
			}
		}
	}
?>
}
<?
}
?>