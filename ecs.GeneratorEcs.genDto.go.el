<?go
package goecsgen

import (
	"fmt"
	"io"
)

func (g *GeneratorEcs) genDto(wr io.Writer, t *Type) {
	if !t.NeedDto() {
		return
	}
?>

type <?= t.Name ?>Dto struct {
<?
	for f := range t.DtoComponentsSeq() {
		if f.IsEcsRef() {
			if f.IsArray() {
?>
	<?= f.GetName() ?> []ecs.Id
<?
			} else {
?>
	<?= f.GetName() ?> ecs.Id
<?
			}
		} else {
?>
	<?= f.GetName() ?> <?= f.GetTypeName() ?>
<?
		}
	}
?>
}

func (c <?= t.Name ?>) Dto() <?= t.Name ?>Dto {
	return <?= t.Name ?>Dto{
<?
	for f := range t.DtoComponentsSeq() {
		if f.IsEcsRef() {
			if f.IsArray() {
?>
		<?= f.GetName() ?>: slicesex.Transform(c.<?= f.GetName() ?>, ecs.RefId),
<?
			} else {
?>
		<?= f.GetName() ?>: c.<?= f.GetName() ?>.Id,
<?
			}
		} else {
?>
		<?= f.GetName() ?>: c.<?= f.GetName() ?>,
<?
		}
	}
?>
	}
}

func (c <?= t.Name ?>) FromDto(dto <?= t.Name ?>Dto) <?= t.Name ?> {
<?
	for f := range t.DtoComponentsSeq() {
		if f.IsEcsRef() {
			if f.IsArray() {
?>
	c.<?= f.GetName() ?> = slicesex.Transform(dto.<?= f.GetName() ?>, ecs.MakeRef[<?= f.GetType().GetName() ?>])
<?
			} else {
?>
	c.<?= f.GetName() ?> = ecs.MakeRef[<?= f.GetType().GetName() ?>](dto.<?= f.GetName() ?>)
<?
			}
		} else {
?>
	c.<?= f.GetName() ?> = dto.<?= f.GetName() ?>
<?
		}
	}
?>
	return c
}
<?
}
?>