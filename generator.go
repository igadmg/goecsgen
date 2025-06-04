package goecsgen

import (
	"bytes"
	"cmp"
	"fmt"
	"go/ast"
	"iter"
	"log"
	"net/rpc"
	"os"
	"slices"

	"deedles.dev/xiter"
	"github.com/igadmg/gogen/core"
	"gonum.org/v1/gonum/graph"
	"gonum.org/v1/gonum/graph/encoding"
	"gonum.org/v1/gonum/graph/simple"
)

type GeneratorEcs struct {
	core.GeneratorBaseT

	components map[string]*Type
	entities   map[string]*Type
	queries    map[string]*Type
	features   map[string]*Type
	systems    map[string]*Type

	EntitesByQueries map[*Type][]*Type
}

var _ core.Generator = (*GeneratorEcs)(nil)

func (g *GeneratorEcs) MarshalYAML() (interface{}, error) {
	return map[string]any{
		"components": g.components,
		"entities":   g.entities,
		"queries":    g.queries,
		"features":   g.features,
		"systems":    g.systems,
	}, nil
}

type ArgParam struct {
	Value int
	Name  string
}

type ArgType struct {
	FileName  string
	Data      []int
	Params    []ArgParam
	Component *core.TokenDto
	//Entities   map[string]*Type
	//Queries    map[string]*Type
	//Features   map[string]*Type
	//Systems    map[string]*Type
}

type ReplyType struct {
}

func (s GeneratorEcs) Marshal(args *ArgType, reply *ReplyType) error {
	log.Print("Получили запрос на маршализацию " + args.FileName)
	return nil
}

func (s *GeneratorEcs) Yaml(fileName string) {
	// Подключаемся к RPC-серверу
	client, err := rpc.Dial("tcp", "localhost:1234")
	if err != nil {
		fmt.Println("Ошибка при подключении к серверу:", err)
		os.Exit(1)
	}
	defer client.Close()

	//testType := core.NewType(&core.Package{Name: "test"})
	//testType.Name = "TestType"
	// Синхронный вызов Multiply
	args := &ArgType{
		FileName: fileName,
		Data:     []int{1, 2, 3, 4, 5},
		Params: []ArgParam{
			{
				Value: 13,
				Name:  "thiriteen",
			},
			{
				Value: 40,
				Name:  "manymany",
			},
		},
		Component: &core.TokenDto{
			Name:    "TestToken",
			Package: "test",
			Tag: core.TagData{
				"component": nil,
			},
		},
		//	Components: s.components,
		//	Entities:   s.entities,
		//	Queries:    s.queries,
		//	Features:   s.features,
		//	Systems:    s.systems,
	}
	var reply ReplyType
	multiplyCall := client.Go("GeneratorEcs.Marshal", args, &reply, nil)
	<-multiplyCall.Done // Ждем завершения вызова
	if multiplyCall.Error != nil {
		fmt.Println("Ошибка при асинхронном вызове Arith.Multiply:", multiplyCall.Error)
	}

	multiplyCall = client.Go("GeneratorEcs.Marshal", args, &reply, nil)
	<-multiplyCall.Done // Ждем завершения вызова
	if multiplyCall.Error != nil {
		fmt.Println("Ошибка при асинхронном вызове Arith.Multiply:", multiplyCall.Error)
	}

	multiplyCall = client.Go("GeneratorEcs.Marshal", args, &reply, nil)
	<-multiplyCall.Done // Ждем завершения вызова
	if multiplyCall.Error != nil {
		fmt.Println("Ошибка при асинхронном вызове Arith.Multiply:", multiplyCall.Error)
	}
}

func NewGeneratorEcs() core.Generator {
	g := &GeneratorEcs{
		GeneratorBaseT:   core.MakeGeneratorB("ecs", "ecs"),
		components:       map[string]*Type{},
		entities:         map[string]*Type{},
		queries:          map[string]*Type{},
		features:         map[string]*Type{},
		systems:          map[string]*Type{},
		EntitesByQueries: map[*Type][]*Type{},
	}
	g.G = g
	return g
}

func (g *GeneratorEcs) NewType(pkg *core.Package, t core.TypeI, spec *ast.TypeSpec) (core.TypeI, error) {
	if t == nil {
		t = NewType(pkg)
		defer func() {
			g.Types[t.GetFullName()] = t
		}()
	}

	switch et := t.(type) {
	case *Type:
		var err error
		_, err = g.GeneratorBaseT.NewType(pkg, &et.Type, spec)
		if err != nil {
			return nil, err
		}

		et.EType = Tag(et.Tag).GetEcsTag()

		switch Tag(et.Tag).GetEcsTag() {
		case EcsArchetype:
			g.entities[et.Name] = et
		case EcsFeature:
			g.features[et.Name] = et
		case EcsComponent:
			g.components[et.Name] = et
		case EcsQuery:
			g.queries[et.Name] = et
		case EcsSystem:
			g.systems[et.Name] = et
		}
	}

	return t, nil
}

func (g *GeneratorEcs) NewField(f core.FieldI, spec *ast.Field) (core.FieldI, error) {
	if f == nil {
		f = &Field{}
		defer func() {
			g.Fields = append(g.Fields, f)
		}()
	}

	switch ef := f.(type) {
	case *Field:
		var err error

		_, err = g.GeneratorBaseT.NewField(&ef.Field, spec)
		if err != nil {
			return nil, err
		}
	}

	return f, nil
}

func (g *GeneratorEcs) NewFunc(f core.FuncI, spec *ast.FuncDecl) (core.FuncI, error) {
	if f == nil {
		f = &core.Func{}
		defer func() {
			if id := f.GetFullTypeName(); id != "" {
				g.Funcs[id] = append(g.Funcs[id], f)
			}
		}()
	}

	switch ef := f.(type) {
	case *core.Func:
		var err error

		_, err = g.GeneratorBaseT.NewFunc(ef, spec)
		if err != nil {
			return nil, err
		}
	}

	return f, nil
}

func (g *GeneratorEcs) GetEcsType(name string) (t EcsTypeI, ok bool) {
	if t, ok := g.GetType(name); ok {
		et, ok := t.(EcsTypeI)
		return et, ok
	}

	return nil, ok
}

func (g *GeneratorEcs) Prepare() {
	g.GeneratorBaseT.Prepare()
	g.EntitesByQueries = map[*Type][]*Type{}

	for _, q := range g.queries {
		g.EntitesByQueries[q] = []*Type{}
	}
	for _, e := range g.entities {
		ec := map[*Type]struct{}{}
		for c := range EnumFieldsSeq(e.StructComponentsSeq()) {
			ct, ok := CastType(c.Type)
			if !ok {
				continue
			}

			for bf := range ct.BasesSeq() {
				bt, ok := CastType(bf.GetType())
				if !ok {
					continue
				}

				ec[bt] = struct{}{}
			}

			ec[ct] = struct{}{}
		}
		for _, q := range g.queries {
			for c := range EnumFieldsSeq(q.StructComponentsSeq()) {
				ct, ok := CastType(c.Type)
				if !ok {
					continue
				}

				if _, ok := ec[ct]; !ok {
					goto skip_query
				}
			}

			g.EntitesByQueries[q] = append(g.EntitesByQueries[q], e)
		skip_query:
		}
	}
}

func (g *GeneratorEcs) Generate(pkg *core.Package) bytes.Buffer {
	source := bytes.Buffer{}
	g.Pkg = pkg
	g.Prepare()
	g.generate(&source)
	return source
}

type QueriesSeqItem struct {
	Query    *Type
	Archs    []*Type
	AnyLocal bool
}

func (g *GeneratorEcs) QueriesSeq() iter.Seq[QueriesSeqItem] {
	return func(yield func(QueriesSeqItem) bool) {
		for q, es := range g.EntitesByQueries {
			if q.GetPackage() != g.Pkg && !g.Pkg.Above(q.GetPackage()) {
				continue
			}

			//anyLocal := false
			anyLocal := len(es) == 0 // if es == 0 then all archs are local
			archs := slices.Collect(
				xiter.Filter(slices.Values(es), func(t *Type) bool {
					if t.Package == g.Pkg {
						anyLocal = true
						return true
					}
					return g.Pkg.Above(t.Package)
				}))
			slices.SortStableFunc(archs, func(a, b *Type) int {
				return cmp.Compare(a.Name, b.Name)
			})

			if q.GetPackage() != g.Pkg && len(archs) == 0 {
				continue
			}

			if !yield(QueriesSeqItem{
				Query:    q,
				AnyLocal: anyLocal,
				Archs:    archs,
			}) {
				return
			}
		}
	}
}

type ecsGraph struct {
	*simple.DirectedGraph
}

type ecsNode struct {
	graph.Node
	Type *Type
}

func (g ecsNode) DOTID() string {
	return g.Type.Name
}

func (g ecsNode) Attributes() (attrs []encoding.Attribute) {
	switch g.Type.EType {
	case EcsArchetype:
		attrs = append(attrs, encoding.Attribute{
			Key:   "shape",
			Value: "box",
		})
	}

	return
}

func (g *GeneratorEcs) Graph() graph.Graph {
	r := ecsGraph{
		DirectedGraph: simple.NewDirectedGraph(),
	}

	enodes := map[string]ecsNode{}
	for _, i := range g.entities {
		n := ecsNode{Node: r.NewNode(), Type: i}
		r.AddNode(n)
		enodes[i.Name] = n
	}

	cnodes := map[string]ecsNode{}
	for _, i := range g.components {
		n := ecsNode{Node: r.NewNode(), Type: i}
		r.AddNode(n)
		cnodes[i.Name] = n
	}

	for _, e := range g.entities {
		en := enodes[e.Name]
		for cf := range e.StructComponentsSeq() {
			if ct := cf.GetType(); ct != nil {
				cn := cnodes[ct.GetName()]
				r.SetEdge(r.NewEdge(en, cn))
			}
		}
	}

	for _, c := range g.components {
		cn := cnodes[c.Name]
		for bf := range c.BasesSeq() {
			if bt := bf.GetType(); bt != nil {
				if bn, ok := cnodes[bt.GetName()]; ok {
					r.SetEdge(r.NewEdge(cn, bn))
				}
			}
		}
	}

	return r
}
