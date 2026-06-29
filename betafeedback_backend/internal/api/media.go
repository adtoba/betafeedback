package api

import (
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

// maxUploadBytes caps a single attachment (screenshot or screen recording).
const maxUploadBytes = 50 << 20 // 50 MB

// allowedExts are the file extensions accepted for uploads.
var allowedExts = map[string]bool{
	".png": true, ".jpg": true, ".jpeg": true, ".gif": true, ".webp": true,
	".heic": true, ".mp4": true, ".mov": true, ".webm": true, ".m4v": true,
}

// uploadMedia stores a single uploaded image or video on disk (under MediaDir,
// namespaced by project) and returns a URL the client can attach to feedback.
func (s *Server) uploadMedia(w http.ResponseWriter, r *http.Request, userID string) {
	projectID := r.PathValue("id")
	if _, ok := s.requireMember(w, r, projectID, userID); !ok {
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, maxUploadBytes+(1<<20))
	if err := r.ParseMultipartForm(8 << 20); err != nil {
		writeError(w, http.StatusBadRequest, "invalid or oversized upload")
		return
	}
	defer r.MultipartForm.RemoveAll()

	file, header, err := r.FormFile("file")
	if err != nil {
		writeError(w, http.StatusBadRequest, "missing file")
		return
	}
	defer file.Close()

	if header.Size > maxUploadBytes {
		writeError(w, http.StatusRequestEntityTooLarge, "file too large (max 50 MB)")
		return
	}

	contentType := header.Header.Get("Content-Type")
	if !strings.HasPrefix(contentType, "image/") && !strings.HasPrefix(contentType, "video/") {
		writeError(w, http.StatusUnsupportedMediaType, "only images and videos are allowed")
		return
	}

	ext := strings.ToLower(filepath.Ext(header.Filename))
	if !allowedExts[ext] {
		writeError(w, http.StatusUnsupportedMediaType, "unsupported file type")
		return
	}

	rel := filepath.Join(projectID, randomToken(24)+ext)
	dest := filepath.Join(s.cfg.MediaDir, rel)
	if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
		s.serverError(w, "create media dir", err)
		return
	}

	out, err := os.Create(dest)
	if err != nil {
		s.serverError(w, "create media file", err)
		return
	}
	defer out.Close()
	if _, err := io.Copy(out, file); err != nil {
		s.serverError(w, "write media file", err)
		return
	}

	label := filepath.Base(header.Filename)
	if label == "" || label == "." {
		if strings.HasPrefix(contentType, "video/") {
			label = "Recording"
		} else {
			label = "Screenshot"
		}
	}

	writeJSON(w, http.StatusCreated, map[string]string{
		"url":          "/media/" + filepath.ToSlash(rel),
		"content_type": contentType,
		"label":        label,
	})
}

// mediaFileServer serves uploaded files from MediaDir, refusing directory paths.
func (s *Server) mediaFileServer() http.Handler {
	fs := http.FileServer(http.Dir(s.cfg.MediaDir))
	return http.StripPrefix("/media/", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasSuffix(r.URL.Path, "/") {
			http.NotFound(w, r)
			return
		}
		fs.ServeHTTP(w, r)
	}))
}
