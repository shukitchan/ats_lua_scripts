# Sample Backend Integration Examples for Cache Groups
# This file shows how different backend applications can use Cache Groups

# =============================================================================
# NGINX Configuration Example
# =============================================================================

# In your NGINX server block, add Cache-Groups headers:
server {
    listen 80;
    server_name backend.example.com;
    
    location /api/users/ {
        # Add cache groups for user-related APIs
        add_header Cache-Groups '"api-v1", "users", "profiles"';
        
        # Your backend configuration
        proxy_pass http://app_servers;
    }
    
    location /api/products/ {
        # Add cache groups for product catalog
        add_header Cache-Groups '"api-v1", "products", "catalog"';
        
        proxy_pass http://app_servers;
    }
    
    location /api/admin/invalidate {
        # Invalidate cache groups after admin actions
        add_header Cache-Group-Invalidation '"products", "catalog", "users"';
        
        proxy_pass http://app_servers;
    }
}

# =============================================================================
# Apache HTTP Server Configuration Example  
# =============================================================================

# In your Apache virtual host or .htaccess:
<VirtualHost *:80>
    ServerName backend.example.com
    
    # For API endpoints
    <LocationMatch "^/api/v1/users">
        Header always set Cache-Groups '"api-v1", "users", "profiles"'
    </LocationMatch>
    
    <LocationMatch "^/api/v1/products">
        Header always set Cache-Groups '"api-v1", "products", "inventory"'
    </LocationMatch>
    
    # For invalidation endpoints (POST/PUT/DELETE only)
    <LocationMatch "^/api/v1/admin/.*">
        Header always set Cache-Group-Invalidation '"users", "products", "cache-all"'
    </LocationMatch>
</VirtualHost>

# =============================================================================
# Node.js Express Application Example
# =============================================================================

const express = require('express');
const app = express();

// Middleware to add cache groups
const addCacheGroups = (groups) => {
    return (req, res, next) => {
        res.set('Cache-Groups', groups.map(g => `"${g}"`).join(', '));
        next();
    };
};

const invalidateCacheGroups = (groups) => {
    return (req, res, next) => {
        if (!['GET', 'HEAD', 'OPTIONS', 'TRACE'].includes(req.method)) {
            res.set('Cache-Group-Invalidation', groups.map(g => `"${g}"`).join(', '));
        }
        next();
    };
};

// User profile endpoints
app.get('/api/users/:id', 
    addCacheGroups(['api-v1', 'users', 'user-profiles']),
    (req, res) => {
        // Return user data
        res.json({ userId: req.params.id });
    }
);

// Product catalog endpoints
app.get('/api/products/:id',
    addCacheGroups(['api-v1', 'products', 'catalog']),
    (req, res) => {
        // Return product data
        res.json({ productId: req.params.id });
    }
);

// User update endpoint (invalidates user cache)
app.put('/api/users/:id',
    invalidateCacheGroups(['users', 'user-profiles']),
    (req, res) => {
        // Update user
        res.json({ success: true });
    }
);

# =============================================================================
# Python Django Application Example
# =============================================================================

from django.http import HttpResponse
from django.views.decorators.cache import cache_page

class CacheGroupsMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)
        
        # Add cache groups based on URL patterns
        if request.path.startswith('/api/users/'):
            response['Cache-Groups'] = '"api-v1", "users", "profiles"'
        elif request.path.startswith('/api/products/'):
            response['Cache-Groups'] = '"api-v1", "products", "catalog"'
        elif request.path.startswith('/static/'):
            response['Cache-Groups'] = '"static-assets", "css", "js"'
            
        # Add invalidation for unsafe methods
        if request.method in ['POST', 'PUT', 'DELETE', 'PATCH']:
            if 'user' in request.path:
                response['Cache-Group-Invalidation'] = '"users", "profiles"'
            elif 'product' in request.path:
                response['Cache-Group-Invalidation'] = '"products", "catalog"'
                
        return response

# In your Django settings.py:
MIDDLEWARE = [
    'your_app.middleware.CacheGroupsMiddleware',
    # ... other middleware
]

# =============================================================================
# PHP Application Example
# =============================================================================

<?php
// CacheGroups helper class
class CacheGroups {
    public static function addGroups($groups) {
        $header_value = implode(', ', array_map(function($g) {
            return '"' . $g . '"';
        }, $groups));
        header("Cache-Groups: $header_value");
    }
    
    public static function invalidateGroups($groups) {
        if (!in_array($_SERVER['REQUEST_METHOD'], ['GET', 'HEAD', 'OPTIONS', 'TRACE'])) {
            $header_value = implode(', ', array_map(function($g) {
                return '"' . $g . '"';
            }, $groups));
            header("Cache-Group-Invalidation: $header_value");
        }
    }
}

// Usage in your PHP application:

// User profile page
if (strpos($_SERVER['REQUEST_URI'], '/users/') !== false) {
    CacheGroups::addGroups(['api-v1', 'users', 'profiles']);
    // ... render user profile
}

// Product page  
if (strpos($_SERVER['REQUEST_URI'], '/products/') !== false) {
    CacheGroups::addGroups(['api-v1', 'products', 'catalog']);
    // ... render product details
}

// User update endpoint
if ($_SERVER['REQUEST_METHOD'] === 'POST' && strpos($_SERVER['REQUEST_URI'], '/users/') !== false) {
    CacheGroups::invalidateGroups(['users', 'profiles']);
    // ... handle user update
}

# =============================================================================
# Java Spring Boot Application Example
# =============================================================================

@RestController
public class ApiController {
    
    @GetMapping("/api/users/{id}")
    public ResponseEntity<User> getUser(@PathVariable String id, HttpServletResponse response) {
        response.setHeader("Cache-Groups", "\"api-v1\", \"users\", \"profiles\"");
        
        User user = userService.findById(id);
        return ResponseEntity.ok(user);
    }
    
    @GetMapping("/api/products/{id}")
    public ResponseEntity<Product> getProduct(@PathVariable String id, HttpServletResponse response) {
        response.setHeader("Cache-Groups", "\"api-v1\", \"products\", \"catalog\"");
        
        Product product = productService.findById(id);
        return ResponseEntity.ok(product);
    }
    
    @PostMapping("/api/users/{id}")
    public ResponseEntity<String> updateUser(@PathVariable String id, HttpServletResponse response) {
        response.setHeader("Cache-Group-Invalidation", "\"users\", \"profiles\"");
        
        // Update user logic
        return ResponseEntity.ok("User updated");
    }
}

# =============================================================================
# Best Practices for Backend Integration
# =============================================================================

1. **Group Naming Strategy:**
   - Use descriptive, hierarchical names: "api-v1", "users", "user-123"
   - Include version information: "api-v1", "api-v2"
   - Group by functionality: "products", "categories", "search-results"

2. **Group Granularity:**
   - Fine-grained: "user-123", "product-456" (specific entities)
   - Medium-grained: "users", "products" (entity types)
   - Coarse-grained: "api-v1", "frontend" (broad categories)

3. **Invalidation Patterns:**
   - User updates: Invalidate "user-{id}", "users", "sessions"
   - Product updates: Invalidate "product-{id}", "products", "catalog"
   - System updates: Invalidate "api-v1", "cache-all"

4. **Security Considerations:**
   - Only add groups that are safe to invalidate together
   - Use origin isolation (groups are per-origin)
   - Don't expose sensitive information in group names

5. **Performance Tips:**
   - Limit to essential groups (max 32 per response)
   - Use consistent group names across related resources
   - Clean up stale groups periodically