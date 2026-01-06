const request = require('supertest');
const app = require('../src/index');
const todosRouter = require('../src/routes/todos');

describe('Todo API', () => {
  beforeEach(() => {
    todosRouter.store.clear();
  });

  describe('GET /api/todos', () => {
    it('returns empty array initially', async () => {
      const res = await request(app).get('/api/todos');
      expect(res.status).toBe(200);
      expect(res.body.todos).toEqual([]);
    });

    it('returns all todos', async () => {
      todosRouter.store.create('Task 1');
      todosRouter.store.create('Task 2');

      const res = await request(app).get('/api/todos');
      expect(res.status).toBe(200);
      expect(res.body.todos).toHaveLength(2);
    });
  });

  describe('POST /api/todos', () => {
    it('creates todo with title', async () => {
      const res = await request(app)
        .post('/api/todos')
        .send({ title: 'New task' });

      expect(res.status).toBe(201);
      expect(res.body.id).toBeDefined();
      expect(res.body.title).toBe('New task');
      expect(res.body.completed).toBe(false);
    });

    it('returns 400 if title missing', async () => {
      const res = await request(app)
        .post('/api/todos')
        .send({});

      expect(res.status).toBe(400);
    });

    it('returns 400 if title empty', async () => {
      const res = await request(app)
        .post('/api/todos')
        .send({ title: '  ' });

      expect(res.status).toBe(400);
    });
  });

  describe('PUT /api/todos/:id', () => {
    it('updates todo title', async () => {
      const todo = todosRouter.store.create('Original');

      const res = await request(app)
        .put(`/api/todos/${todo.id}`)
        .send({ title: 'Updated' });

      expect(res.status).toBe(200);
      expect(res.body.title).toBe('Updated');
    });

    it('updates todo completed status', async () => {
      const todo = todosRouter.store.create('Task');

      const res = await request(app)
        .put(`/api/todos/${todo.id}`)
        .send({ completed: true });

      expect(res.status).toBe(200);
      expect(res.body.completed).toBe(true);
    });

    it('returns 404 for non-existent id', async () => {
      const res = await request(app)
        .put('/api/todos/non-existent')
        .send({ title: 'Test' });

      expect(res.status).toBe(404);
    });
  });

  describe('DELETE /api/todos/:id', () => {
    it('deletes existing todo', async () => {
      const todo = todosRouter.store.create('To delete');

      const res = await request(app)
        .delete(`/api/todos/${todo.id}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    it('returns 404 for non-existent id', async () => {
      const res = await request(app)
        .delete('/api/todos/non-existent');

      expect(res.status).toBe(404);
      expect(res.body.error).toBe('Todo not found');
    });

    it('removes todo from list after deletion', async () => {
      const todo = todosRouter.store.create('To delete');

      await request(app).delete(`/api/todos/${todo.id}`);

      const listRes = await request(app).get('/api/todos');
      expect(listRes.body.todos).toHaveLength(0);
    });

    it('only deletes specified todo', async () => {
      const todo1 = todosRouter.store.create('Keep this');
      const todo2 = todosRouter.store.create('Delete this');

      await request(app).delete(`/api/todos/${todo2.id}`);

      const listRes = await request(app).get('/api/todos');
      expect(listRes.body.todos).toHaveLength(1);
      expect(listRes.body.todos[0].id).toBe(todo1.id);
    });

    it('cannot delete same todo twice', async () => {
      const todo = todosRouter.store.create('Delete once');

      const firstDelete = await request(app).delete(`/api/todos/${todo.id}`);
      expect(firstDelete.status).toBe(200);

      const secondDelete = await request(app).delete(`/api/todos/${todo.id}`);
      expect(secondDelete.status).toBe(404);
    });
  });
});
