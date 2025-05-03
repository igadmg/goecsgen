<?go
package goecsgen

import (

	"fmt"
	"io"
)

func (g *GeneratorEcs) generateSystem(wr io.Writer, t *Type) {
?>

var _ ecs.System = (*<?= t.Name ?>)(nil)
<?
}
?>