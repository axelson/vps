// Command lint checks that a file or directory works as a file_hosting bundle,
// which is served under /<name>/:
//
//   - a top-level index.html exists (a single .html file becomes index.html)
//   - no root-absolute references ("/app.js"), which would escape the bundle
//   - relative references point at files that exist in the bundle
//   - the total size is within the cap
//
// External URLs are listed so the caller knows what the bundle depends on.
// Exits 1 when there are errors, 0 otherwise.
package main

import (
	"fmt"
	"io/fs"
	"net/url"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

const maxBundleBytes = 25 * 1024 * 1024

var (
	htmlAttr  = regexp.MustCompile(`(?i)\b(?:src|href|action|poster|data)\s*=\s*(?:"([^"]*)"|'([^']*)')`)
	srcset    = regexp.MustCompile(`(?i)\bsrcset\s*=\s*(?:"([^"]*)"|'([^']*)')`)
	cssURL    = regexp.MustCompile(`url\(\s*(?:"([^"]*)"|'([^']*)'|([^)"'\s]+))\s*\)`)
	cssImport = regexp.MustCompile(`@import\s+(?:"([^"]*)"|'([^']*)')`)
	jsImport  = regexp.MustCompile(`(?:\bimport\s*(?:[\w*{}\s,]+\s+from\s*)?|\bexport\s+[\w*{}\s,]+\s+from\s*|\bimport\s*\(\s*)(?:"([^"]*)"|'([^']*)')`)
	// Strings passed to APIs that resolve against the page URL rather than the script.
	jsPageRef  = regexp.MustCompile(`\b(?:fetch|new\s+Worker|new\s+SharedWorker|new\s+URL|importScripts)\s*\(\s*(?:"([^"]*)"|'([^']*)'|` + "`([^`]*)`" + `)`)
	scriptTag  = regexp.MustCompile(`(?is)(<script\b[^>]*>)(.*?)(</script>)`)
	styleTag   = regexp.MustCompile(`(?is)(<style\b[^>]*>)(.*?)(</style>)`)
	styleAttr  = regexp.MustCompile(`(?i)\bstyle\s*=\s*(?:"([^"]*)"|'([^']*)')`)
	schemeLike = regexp.MustCompile(`^[a-zA-Z][a-zA-Z0-9+.-]*:`)
)

type kind int

const (
	// Resolved relative to the referencing file.
	fileRelative kind = iota
	// Resolved relative to the page (the bundle's index.html, usually) at runtime.
	pageRelative
)

type linter struct {
	root         string
	single       bool // a single file being published as index.html
	singleSource string
	files        map[string]bool
	errors       []string
	warnings     []string
	externals    map[string][]string
}

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintln(os.Stderr, "usage: lint <file.html | directory>")
		os.Exit(2)
	}

	l, err := newLinter(os.Args[1])
	if err != nil {
		fmt.Fprintln(os.Stderr, "lint:", err)
		os.Exit(2)
	}
	l.run()
	l.report()

	if len(l.errors) > 0 {
		os.Exit(1)
	}
}

func newLinter(target string) (*linter, error) {
	info, err := os.Stat(target)
	if err != nil {
		return nil, err
	}
	l := &linter{files: map[string]bool{}, externals: map[string][]string{}}

	if info.IsDir() {
		l.root = target
		var total int64
		err = filepath.WalkDir(target, func(p string, d fs.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if d.IsDir() && skipDir(d.Name()) && p != target {
				return filepath.SkipDir
			}
			if d.Type()&fs.ModeSymlink != 0 {
				rel, _ := filepath.Rel(target, p)
				l.errorf("%s: symlinks are not allowed in a bundle (copy the file instead)", rel)
				return nil
			}
			if d.Type().IsRegular() && !skipFile(d.Name()) {
				rel, _ := filepath.Rel(target, p)
				l.files[filepath.ToSlash(rel)] = true
				fi, err := d.Info()
				if err != nil {
					return err
				}
				total += fi.Size()
			}
			return nil
		})
		if err != nil {
			return nil, err
		}
		if total > maxBundleBytes {
			l.errorf("bundle is %d bytes; the cap is %d", total, maxBundleBytes)
		}
		if !l.files["index.html"] {
			l.errorf("missing top-level index.html")
		}
	} else {
		ext := strings.ToLower(filepath.Ext(target))
		if ext != ".html" && ext != ".htm" {
			return nil, fmt.Errorf("a single file must be .html (it is published as index.html): %s", target)
		}
		if info.Size() > maxBundleBytes {
			l.errorf("file is %d bytes; the cap is %d", info.Size(), maxBundleBytes)
		}
		l.root = filepath.Dir(target)
		l.single = true
		l.files["index.html"] = true
		l.singleSource = target
	}
	return l, nil
}

// source is the on-disk path of the bundle file rel.
func (l *linter) source(rel string) string {
	if l.single {
		return l.singleSource
	}
	return filepath.Join(l.root, filepath.FromSlash(rel))
}

func (l *linter) run() {
	names := make([]string, 0, len(l.files))
	for f := range l.files {
		names = append(names, f)
	}
	sort.Strings(names)

	for _, rel := range names {
		ext := strings.ToLower(path.Ext(rel))
		if ext != ".html" && ext != ".htm" && ext != ".css" && ext != ".js" && ext != ".mjs" {
			continue
		}
		data, err := os.ReadFile(l.source(rel))
		if err != nil {
			l.errorf("%s: %v", rel, err)
			continue
		}
		text := string(data)

		switch ext {
		case ".html", ".htm":
			l.checkHTML(rel, text)
		case ".css":
			l.checkCSS(rel, text)
		default:
			l.checkJS(rel, text)
		}
	}
}

func (l *linter) checkHTML(rel, text string) {
	// Inline scripts and styles first, then blank them so their contents aren't
	// mistaken for attributes.
	for _, m := range scriptTag.FindAllStringSubmatch(text, -1) {
		l.checkJS(rel, m[2])
	}
	for _, m := range styleTag.FindAllStringSubmatch(text, -1) {
		l.checkCSS(rel, m[2])
	}
	markup := scriptTag.ReplaceAllString(styleTag.ReplaceAllString(text, "$1$3"), "$1$3")

	for _, m := range htmlAttr.FindAllStringSubmatch(markup, -1) {
		l.check(rel, first(m[1:]), fileRelative)
	}
	for _, m := range srcset.FindAllStringSubmatch(markup, -1) {
		for _, candidate := range strings.Split(first(m[1:]), ",") {
			if fields := strings.Fields(candidate); len(fields) > 0 {
				l.check(rel, fields[0], fileRelative)
			}
		}
	}
	for _, m := range styleAttr.FindAllStringSubmatch(markup, -1) {
		l.checkCSS(rel, first(m[1:]))
	}
}

func (l *linter) checkCSS(rel, text string) {
	for _, m := range cssURL.FindAllStringSubmatch(text, -1) {
		l.check(rel, first(m[1:]), fileRelative)
	}
	for _, m := range cssImport.FindAllStringSubmatch(text, -1) {
		l.check(rel, first(m[1:]), fileRelative)
	}
}

func (l *linter) checkJS(rel, text string) {
	for _, m := range jsImport.FindAllStringSubmatch(text, -1) {
		spec := first(m[1:])
		if spec != "" && !strings.HasPrefix(spec, ".") && !strings.HasPrefix(spec, "/") && !schemeLike.MatchString(spec) {
			l.warnf("%s: bare import %q only works with an import map", rel, spec)
			continue
		}
		l.check(rel, spec, fileRelative)
	}
	for _, m := range jsPageRef.FindAllStringSubmatch(text, -1) {
		ref := first(m[1:])
		if strings.Contains(ref, "${") {
			if strings.HasPrefix(ref, "/") && !strings.HasPrefix(ref, "//") {
				l.errorf("%s: root-absolute reference %q escapes the bundle; make it relative", rel, ref)
			}
			continue
		}
		l.check(rel, ref, pageRelative)
	}
}

// check classifies one reference found in file rel.
func (l *linter) check(rel, ref string, k kind) {
	ref = strings.TrimSpace(ref)
	switch {
	case ref == "" || strings.HasPrefix(ref, "#") || strings.HasPrefix(ref, "{{"):
		return
	case strings.HasPrefix(ref, "//"):
		l.external("https:"+ref, rel)
		return
	case schemeLike.MatchString(ref):
		scheme := strings.ToLower(strings.SplitN(ref, ":", 2)[0])
		if scheme == "http" || scheme == "https" || scheme == "ws" || scheme == "wss" {
			l.external(ref, rel)
		}
		return
	case strings.HasPrefix(ref, "/"):
		l.errorf("%s: root-absolute reference %q escapes the bundle; make it relative", rel, ref)
		return
	}

	target := ref
	if u, err := url.Parse(ref); err == nil {
		target = u.Path
	}
	if target == "" {
		return
	}

	base := path.Dir(rel)
	if l.single {
		base = "."
	}
	candidates := []string{path.Clean(path.Join(base, target))}
	if k == pageRelative {
		// Resolved against the page at runtime; accept the bundle root too.
		candidates = append(candidates, path.Clean(target))
	}

	for _, c := range candidates {
		if c == ".." || strings.HasPrefix(c, "../") {
			continue
		}
		if l.exists(c, strings.HasSuffix(target, "/")) {
			return
		}
	}

	if strings.HasPrefix(candidates[0], "../") || candidates[0] == ".." {
		l.errorf("%s: reference %q points outside the bundle", rel, ref)
	} else if k == pageRelative {
		l.warnf("%s: %q not found in the bundle (resolved against the page at runtime)", rel, ref)
	} else {
		l.errorf("%s: reference %q not found in the bundle", rel, ref)
	}
}

func (l *linter) exists(p string, dir bool) bool {
	if l.files[p] {
		return true
	}
	if p == "." {
		return l.files["index.html"]
	}
	return l.files[path.Join(p, "index.html")] || (dir && l.files[p+"/index.html"])
}

func (l *linter) external(u, rel string) {
	for _, existing := range l.externals[u] {
		if existing == rel {
			return
		}
	}
	l.externals[u] = append(l.externals[u], rel)
}

func (l *linter) errorf(format string, args ...any) {
	l.errors = append(l.errors, fmt.Sprintf(format, args...))
}

func (l *linter) warnf(format string, args ...any) {
	l.warnings = append(l.warnings, fmt.Sprintf(format, args...))
}

func (l *linter) report() {
	for _, e := range dedupe(l.errors) {
		fmt.Println("ERROR", e)
	}
	for _, w := range dedupe(l.warnings) {
		fmt.Println("WARN ", w)
	}
	urls := make([]string, 0, len(l.externals))
	for u := range l.externals {
		urls = append(urls, u)
	}
	sort.Strings(urls)
	for _, u := range urls {
		fmt.Printf("EXTERNAL %s (in %s)\n", u, strings.Join(l.externals[u], ", "))
	}
	fmt.Printf("%d files, %d errors, %d warnings, %d external URLs\n",
		len(l.files), len(dedupe(l.errors)), len(dedupe(l.warnings)), len(urls))
}

func dedupe(items []string) []string {
	seen := map[string]bool{}
	out := []string{}
	for _, i := range items {
		if !seen[i] {
			seen[i] = true
			out = append(out, i)
		}
	}
	return out
}

func first(groups []string) string {
	for _, g := range groups {
		if g != "" {
			return g
		}
	}
	return ""
}

// Directories and files that publish leaves out of the tarball.
func skipDir(name string) bool  { return name == ".git" || name == "node_modules" }
func skipFile(name string) bool { return name == ".DS_Store" }
