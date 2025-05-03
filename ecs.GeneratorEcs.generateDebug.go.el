<?go
package goecsgen

import (
	"fmt"
	"io"
	"maps"
)

func (g *GeneratorEcs) generateDebug(wr io.Writer) {
?>
type EcsDebugInfo struct {
	EntitiesCount int64
	EntitesCountByName map[string]int64
}

func MakeEcsDebugInfo() EcsDebugInfo {
	return EcsDebugInfo {
		EntitesCountByName: map[string]int64{},
	}
}

func (i EcsDebugInfo) Diff(prev EcsDebugInfo) EcsDebugInfo {
	r := MakeEcsDebugInfo()

	r.EntitiesCount = i.EntitiesCount - prev.EntitiesCount
	r.EntitesCountByName = i.EntitesCountByName
	for k, v := range prev.EntitesCountByName {
		r.EntitesCountByName[k] = i.EntitesCountByName[k] - v
	}

	return r
}

func GetEcsDebugInfo() EcsDebugInfo {
	info := MakeEcsDebugInfo()

<?
	for e := range maps.Values(g.entities) {
		if e.GetPackage() != g.Pkg {
			continue
		}

?>
	c_<?= e.Name ?> := S_<?= e.Name ?>.EntitiesCount()
	info.EntitesCountByName["<?= e.Name ?>"] = c_<?= e.Name ?>
	info.EntitiesCount += c_<?= e.Name ?>
<?
	}
?>

	return info
}
<?
}
?>